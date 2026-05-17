# PanicGuard — Claude Code Context

## What this app is

On-device panic attack triage and intervention for **iOS + watchOS**. Built for the Gemma 4 Good Hackathon (Health & Sciences track). No backend, no cloud, no analytics — everything runs on the device.

Key design insight: during severe panic attacks users cannot open apps. The Watch detects elevated HR silently, sends a haptic, and the phone only activates after the user acknowledges. The Vocal Anchor (reading a phrase aloud) is both a grounding technique and a diagnostic signal.

## Development workflow (follow this every session)

1. **XcodeGen only** — never touch `.xcodeproj` manually. Edit `project.yml` and `.swift` files here, then tell the user to run `xcodegen generate` in the terminal.
2. **TDD strictly** — write the `XCTest` file first for every domain component. Show the test cases, explain them, get confirmation, then implement. Never implement logic without a corresponding test.
3. **Division of labour** — Claude Code edits files in VS Code. User builds and runs in Xcode.

## Tech stack

| Concern | Technology |
|---|---|
| iOS UI | SwiftUI, iOS 17+ |
| watchOS UI | SwiftUI, watchOS 10+ |
| HR sampling | iPhone polls HealthKit on demand (`HKSampleQuery`, last 5 min) via `iPhoneHRFetcher`; Watch writes via `HKAnchoredObjectQuery` |
| LLM inference | LiteRT (LiteRTLM), Gemma 4 E2B quantized, on-device — wrapped by `GemmaAgent` |
| Storage | Core Data |
| Audio / ASR | AVFoundation + SFSpeechRecognizer (offline) |
| Phone↔Watch | WatchConnectivity (`WCSession`) |
| Project generation | XcodeGen (`project.yml`) |

## Bundle IDs

| Target | Bundle ID |
|---|---|
| iOS app | `com.panicguard.app` |
| Watch app | `com.panicguard.app.watchapp` |
| iOS tests | `com.panicguard.tests` |
| Watch tests | `com.panicguard.watchtests` |

## State machine

Multiple entry paths — not strictly linear. All paths through `intervention` must exit via `postEpisodeLog`.

```
                           ONBOARDING
                               │
                               ▼
               ┌───────────── IDLE ─────────────────────────────┐
               │               │ [hrElevationDetected]          │ [directIntervention]
               │ [manualTriage] ▼                                │
               │           WATCHING                              │
               │               │ [elevationSustained]            │
               │               ▼                                 │
               │       SILENT_INVITATION ──[userDismissed]──► IDLE (loop)
               │          │         │
               │    [vocal]│         │ [direct]
               │           │         │
               └──► ACTIVE_TRIAGE   │
                           │         │
                   [triageComplete]  │
                           │         │
                           └────┬────┘
                                ▼
                          INTERVENTION
                                │ [interventionDismissed]
                                ▼
                         POST_EPISODE_LOG
                                │ [logComplete]
                                ▼
                               IDLE (loop)
```

### State transitions

| From | Event | To |
|---|---|---|
| `onboarding` | `onboardingComplete` | `idle` |
| `idle` | `hrElevationDetected` | `watching` |
| `idle` | `userRequestedManualTriage` | `activeTriage` |
| `idle` | `userRequestedDirectIntervention` | `intervention` |
| `watching` | `elevationSustained` | `silentInvitation` |
| `silentInvitation` | `userDismissed` | `idle` |
| `silentInvitation` | `userAcknowledged` | `activeTriage` |
| `silentInvitation` | `userRequestedDirectIntervention` | `intervention` |
| `activeTriage` | `triageComplete(TriageResult)` | `intervention` |
| `intervention` | `interventionDismissed` | `postEpisodeLog` |
| `postEpisodeLog` | `logComplete` | `idle` |
| any | `resetToIdle` | `idle` |

### State descriptions

| State | What happens |
|---|---|
| `onboarding` | Collects age, establishes personal baseline HR, records 12-second vocal calibration to capture `baselineVocalMetrics` (calm-state WPM + pause profile) |
| `idle` | iPhone polls HealthKit on demand via `iPhoneHRFetcher` for Watch HR data |
| `watching` | HR deviated from baseline; verify it's not exercise (step count) |
| `silentInvitation` | 2 min sustained unexplained elevation → soft haptic on Watch. User chooses: dismiss / direct intervention / vocal anchor triage |
| `activeTriage` | Phone wakes. Vocal Anchor displayed + recorded. Step 1+2+3 runs. |
| `intervention` | Phase-based UI driven by `InterventionAction`: breathing guide → grounding exercise (sequential for acute panic), grounding-only (moderate), or medical alert message. 60 BPM haptic anchor. |
| `postEpisodeLog` | Quick user check-in, save episode to Core Data |

`AppStateController` owns the state. `nextStateForDemo()` is a demo-only method to cycle states for UI testing without real sensors.

## Watch role

Watch is the HR sensor and haptic delivery platform. Complex UI lives on the Phone.

| Responsibility | Watch | Phone |
|---|---|---|
| HR sensor (writes to HealthKit) | ✅ | ❌ |
| HealthKit on-demand poll | ❌ | ✅ |
| Silent invitation haptic | ✅ | ❌ |
| Silent invitation UI (2 buttons: dismiss / help now) | ✅ | ❌ |
| Silent invitation UI (3 choices: dismiss / direct / vocal) | ❌ | ✅ |
| Vocal Anchor (mic + ASR) | ❌ | ✅ |
| Intervention breathing guide UI | ✅ | ✅ |
| Quick intervention button (from idle) | ✅ | ✅ |
| Onboarding / Active Triage / Post Episode Log | ❌ | ✅ |

## 3-step hybrid architecture

### Step 1 — HRFeatureExtractor (rule-based)
Input: raw HealthKit HR samples + step count.
Output: `HRFeaturePayload` (mean BPM, slope BPM/min, isMoving, stepsLast5Min).

```json
{ "current_hr_metrics": { "mean_bpm": 145, "slope_bpm_per_min": 30 },
  "context": { "is_moving": false, "steps_last_5min": 12 } }
```

### Step 2 — GemmaAgent (LLM, single-turn prompt)
Uses LiteRT (`LiteRTLMSessionFactory`). **Not** multi-turn tool calling — all context is pre-collected in Swift and embedded in one prompt.

`GemmaAgentPrompts.triagePrompt()` builds the full prompt by:
1. Computing semantic labels in Swift (activity level, slope severity, HR proportionality, vocal rate vs. baseline) — the LLM receives interpreted labels, not raw numbers.
2. Embedding HR features, user baseline, risk ratio, and vocal anchor result.

The LLM outputs `TriageResult` JSON inside `<answer>` tags. No tool calls, no multi-turn.

Output: `TriageResult` (`likelihoodPanic 0–1`, `likelihoodPhysicalAnomaly 0–1`, `confidence high|medium|low`, `reasoningSummary`).

### Step 3 — RuleEngine (deterministic)
Maps `TriageResult` → `InterventionAction` via a fixed priority-ordered threshold table. No LLM. Must stay pure and unit-testable.

| Priority | Condition | Action |
|---|---|---|
| 1 | `physicalAnomaly > 0.70` AND `panic < 0.40` | `.medicalAlert` |
| 2 | `panic >= 0.90` AND `confidence == .high` | `.emergencyContact` |
| 3 | `panic >= 0.75` | `.breathingGuide` |
| 4 | `panic >= 0.40` | `.groundingExercise` |
| 5 | catch-all | `.none` |

`InterventionAction`: `.breathingGuide`, `.groundingExercise`, `.emergencyContact`, `.medicalAlert`, `.none`

**UI behaviour per action:**
- `.breathingGuide` / `.emergencyContact` / `.none`: breathing guide phase → grounding exercise phase (sequential). `.emergencyContact` additionally shows an "alert your emergency contact?" sheet, but only if the user opted in during onboarding (`UserProfile.emergencyContactEnabled`).
- `.groundingExercise`: grounding exercise phase only (no breathing guide first).
- `.medicalAlert`: informational message only ("may not be a panic attack") + episode logged. No intervention animation.

## Directory structure

```
PanicGuard/
  App/              PanicGuardApp.swift, Info.plist, PanicGuard.entitlements
  Domain/
    StateMachine/   AppState.swift, AppStateController.swift
    Agent/          AgentProtocols.swift, HRFeatureExtractor.swift,
                    GemmaAgent.swift, GemmaAgentPrompts.swift,
                    GemmaAgentLiteRTLM.swift, LLMInferring.swift,
                    VocalAnchorManager.swift, iPhoneHRFetcher.swift
    Rules/          RuleEngine.swift, WatchingGuard.swift
  Data/             EpisodeStore.swift, UserProfileStore.swift
  UI/               ContentView.swift + per-state views

PanicGuardWatch/
  App/              PanicGuardWatchApp.swift, Info.plist, PanicGuardWatch.entitlements
  Domain/           AppState.swift, AppStateController.swift,
                    HRSampler.swift, WatchConnector.swift
  UI/               WatchRootView.swift + per-state views
                    (WatchIdleView, WatchWatchingView, WatchSilentInvitationView,
                     WatchInterventionView)

PanicGuardTests/        AppStateControllerTests, HRFeatureExtractorTests,
                        RuleEngineTests, WatchingGuardTests,
                        GemmaAgentTests, GemmaAgentPromptTests,
                        GemmaAgentIntegrationTests, UserProfileStoreTests,
                        VocalAnchorManagerTests, iPhoneHRFetcherTests
PanicGuardWatchTests/   HRSamplerTests
```

## Key shared types (all in AgentProtocols.swift)

- `HRFeaturePayload` — Step 1 output
- `TriageResult` — Step 2 output
- `VocalAnchorResult` — target phrase + ASR transcript (transcript is `nil` if recognition failed) + optional `VocalMetrics`
- `VocalMetrics` — word-level speech timing: WPM, max/mean/total pause seconds, duration. `nil` when recognition failed or < 2 words recognized. Also stored in `UserProfile.baselineVocalMetrics` as the calm-state reference.
- `InterventionAction` — Step 3 output (defined in RuleEngine.swift)

## Coding rules

- No feature flags, no backwards-compat shims, no premature abstractions.
- No comments explaining what code does — only why (hidden constraints, workarounds).
- `fatalError("not implemented")` in every unimplemented body — never silent stubs.
- All domain logic lives behind protocols so tests can inject fakes without mocking HealthKit or the LLM.
- `@MainActor` on `AppStateController` — it drives UI.
- `Speech` import is guarded with `#if canImport(Speech)` because watchOS doesn't have it.
- `InterventionAction` is `String, Codable, Equatable` — needed for Core Data serialization.
- `AppStateController` exposes `@Published lastInterventionAction: InterventionAction` set by `RuleEngine` on `triageComplete`. Direct-intervention paths leave it as `.none` (UI defaults to breathing → grounding).
- `UserProfile.emergencyContactEnabled` gates the emergency contact sheet in `InterventionView`. Defaults to `false` until onboarding stores the preference.
