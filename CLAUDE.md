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
| HR sampling | HealthKit (`HKAnchoredObjectQuery`) |
| LLM inference | MediaPipe LLM Inference API (LiteRT, Gemma 4 E4B, quantized, on-device) |
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

Linear — no skipping states.

```
ONBOARDING → IDLE → WATCHING → SILENT_INVITATION → ACTIVE_TRIAGE → INTERVENTION → POST_EPISODE_LOG
                ↑                                                                        |
                └────────────────────────────────────────────────────────────────────────┘
```

| State | What happens |
|---|---|
| `onboarding` | Collects age, establishes personal baseline HR |
| `idle` | Watch samples HR in background via HealthKit |
| `watching` | HR deviated from baseline; verify it's not exercise (step count) |
| `silentInvitation` | 2 min sustained unexplained elevation → soft haptic on Watch |
| `activeTriage` | Phone wakes. Vocal Anchor displayed + recorded. Step 1+2+3 runs. |
| `intervention` | Breathing guide or grounding exercise UI + 60 BPM haptic anchor |
| `postEpisodeLog` | Quick user check-in, save episode to Core Data |

Events: `onboardingComplete`, `hrElevationDetected`, `elevationSustained`, `userAcknowledged`, `triageComplete(TriageResult)`, `interventionDismissed`, `logComplete`, `resetToIdle`.

`AppStateController` owns the state. `nextStateForDemo()` is a demo-only method to cycle states for UI testing without real sensors.

## 3-step hybrid architecture

### Step 1 — HRFeatureExtractor (rule-based)
Input: raw HealthKit HR samples + step count.
Output: `HRFeaturePayload` (mean BPM, slope BPM/min, isMoving, stepsLast5Min).

```json
{ "current_hr_metrics": { "mean_bpm": 145, "slope_bpm_per_min": 30 },
  "context": { "is_moving": false, "steps_last_5min": 12 } }
```

### Step 2 — GemmaAgent (LLM, multi-step tool calling)
Uses MediaPipe LLM Inference API. Agent calls three tools in sequence:
- `get_user_baseline()` — age + resting HR from `UserProfileStore`
- `get_vocal_anchor_result()` — target phrase vs. ASR transcript (broken/empty transcript → strong panic signal)
- `calculate_risk_ratio(current_hr, baseline_hr)`

Reasons inside `<think>`, then outputs `TriageResult` JSON only.

Output: `TriageResult` (`likelihoodPanic 0–1`, `likelihoodPhysicalAnomaly 0–1`, `confidence high|medium|low`, `reasoningSummary`).

### Step 3 — RuleEngine (deterministic)
Maps `TriageResult` → `InterventionAction` via a fixed threshold table. No LLM. Must stay pure and unit-testable.

`InterventionAction`: `.breathingGuide`, `.groundingExercise`, `.emergencyContact`, `.none`

## Directory structure

```
PanicGuard/
  App/              PanicGuardApp.swift, Info.plist, PanicGuard.entitlements
  Domain/
    StateMachine/   AppState.swift, AppStateController.swift
    Agent/          AgentProtocols.swift, HRFeatureExtractor.swift,
                    GemmaAgent.swift, VocalAnchorManager.swift
    Rules/          RuleEngine.swift, WatchingGuard.swift
  Data/             EpisodeStore.swift, UserProfileStore.swift
  UI/               ContentView.swift + per-state views

PanicGuardWatch/
  App/              PanicGuardWatchApp.swift, Info.plist, PanicGuardWatch.entitlements
  Domain/           HRSampler.swift, WatchConnector.swift
  UI/               WatchRootView.swift + per-state views

PanicGuardTests/        AppStateControllerTests, HRFeatureExtractorTests,
                        RuleEngineTests, WatchingGuardTests
PanicGuardWatchTests/   HRSamplerTests
```

## Key shared types (all in AgentProtocols.swift)

- `HRFeaturePayload` — Step 1 output
- `TriageResult` — Step 2 output
- `VocalAnchorResult` — target phrase + ASR transcript (transcript is `nil` if recognition failed)
- `InterventionAction` — Step 3 output (defined in RuleEngine.swift)

## Coding rules

- No feature flags, no backwards-compat shims, no premature abstractions.
- No comments explaining what code does — only why (hidden constraints, workarounds).
- `fatalError("not implemented")` in every unimplemented body — never silent stubs.
- All domain logic lives behind protocols so tests can inject fakes without mocking HealthKit or the LLM.
- `@MainActor` on `AppStateController` — it drives UI.
- `Speech` import is guarded with `#if canImport(Speech)` because watchOS doesn't have it.
- `InterventionAction` is `String, Codable, Equatable` — needed for Core Data serialization.
