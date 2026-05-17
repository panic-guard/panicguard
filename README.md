# PanicGuard

On-device panic attack triage for iPhone + Apple Watch, powered by Gemma4 via LiteRT. No cloud. No data leaves the device.

---

## The Problem

Panic disorder affects roughly 1 in 75 people. Sufferers know the pattern: a sudden wave of terror, heart pounding at 150+ BPM, chest tightening, breathing collapsing — and the rational mind largely offline. What they need in that moment is not a diagnostic tool but a way to quickly understand what is happening to them and be guided through it.

Two specific needs go unaddressed by existing solutions:

**First, passive detection.** During a severe episode, a person cannot unlock their phone, find an app, and tap a button. Any solution that requires active initiation is already too late for the worst cases. The right trigger is physiological — the body signals the episode before the mind does.

**Second, personalised context.** A heart rate of 130 BPM means something very different for a trained runner versus a sedentary person, or for someone mid-workout versus someone sitting still. Generic thresholds produce false positives that erode trust and false negatives that miss real episodes. Triage needs to be grounded in the individual.

PanicGuard is designed around both constraints. The Apple Watch detects HR elevation silently and in context (cross-referenced against step count to rule out exercise). When elevation is sustained and unexplained, it sends a quiet haptic — no alarm, no disruption. The user acknowledges at their own pace, and only then does the phone activate. The full triage, including LLM inference, runs entirely on-device so there is no network latency at the worst possible moment and no sensitive biometric data ever leaves the device.

---

## How Triage Works

When a user acknowledges a potential episode, the app displays a short phrase and asks them to read it aloud — the **Vocal Anchor**. This serves two purposes simultaneously.

Clinically, reading aloud is a grounding technique: it anchors attention to the present moment and interrupts the cognitive spiral of a panic attack. Diagnostically, it is a distress signal: during severe panic, speech production degrades. A failed or broken transcription is one of the strongest indicators the model sees.

Gemma4 then receives a structured context combining multiple signals:

- **Heart rate features** — mean BPM, rate of rise (BPM/min slope), and whether the elevation is proportionate to observed activity
- **Step count** — used to classify activity level and rule out exercise as a cause
- **Vocal Anchor result** — whether the user could produce coherent speech, and how closely the transcript matched the target phrase
- **Personal baseline** — the user's resting HR and age, collected during onboarding, used to compute a current HR / baseline ratio and contextualise what is abnormal for this individual

The goal is for the model to reason the way a clinician would: *is this person's HR elevated beyond what their activity explains, and are they showing signs of cognitive distress?* The output is not a binary flag but two independent probability scores — `likelihoodPanic` and `likelihoodPhysicalAnomaly` — plus a confidence level and a one-sentence reasoning summary. Both scores can be high simultaneously (arrhythmia-triggered anxiety is a real clinical scenario), which is why they are kept independent.

A deterministic RuleEngine then maps those scores to an intervention, ensuring the final action is always auditable regardless of what the model produced.

---

## Features

- **Silent detection** — Watch monitors HR via HealthKit and sends a haptic after 2 minutes of sustained, unexplained elevation
- **Vocal Anchor** — user reads a short phrase aloud; ASR captures both the grounding effect and a speech coherence signal
- **Multi-signal triage** — Gemma4 weighs HR trajectory, activity level, personal baseline ratio, and vocal anchor result together
- **Personalised context** — resting HR baseline and age collected at onboarding; user-specific reading style and pace are embedded in the prompt for more accurate individualisation
- **Deterministic intervention routing** — RuleEngine maps LLM output to one of four actions with a fixed priority table
- **Multiple intervention modes** — breathing guide, grounding exercise, emergency contact alert, or medical information depending on triage result
- **Multiple entry paths** — Watch haptic flow, manual triage from idle, or direct intervention bypassing triage entirely
- **Episode log** — post-episode check-in saved locally to Core Data; never synced externally

---

## Tech Stack

| Concern | Technology |
|---|---|
| LLM inference | Google AI Edge LiteRT + Gemma4 (quantized, on-device) via [LiteRTLM-Swift-SDK](https://github.com/lanka-ai-foundation/LiteRTLM-Swift-SDK) |
| iOS UI | SwiftUI, iOS 17+ |
| watchOS UI | SwiftUI, watchOS 10+ |
| HR sensor | HealthKit `HKAnchoredObjectQuery` (Watch writes, iPhone polls) |
| Speech recognition | AVFoundation + `SFSpeechRecognizer` (offline) |
| Watch ↔ iPhone | WatchConnectivity (`WCSession`) |
| Storage | Core Data |
| Project generation | XcodeGen |

---

## Architecture: 3-Step Hybrid Pipeline

```
HealthKit HR samples + Step count
         │
         ▼
┌──────────────────────────┐
│  Step 1: HRFeatureExtractor  │  Pure Swift — linear slope regression,
│                              │  activity classification, HR proportionality
└────────────┬─────────────┘
             │  HRFeaturePayload + semantic labels
             ▼
┌──────────────────────────┐
│  Step 2: GemmaAgent          │  Gemma4 via LiteRT — single-turn prompt
│                              │  with HR features, vocal anchor result,
│                              │  and personal baseline; outputs
│                              │  { likelihoodPanic, likelihoodPhysicalAnomaly,
│                              │  confidence, reasoningSummary }
└────────────┬─────────────┘
             │  TriageResult
             ▼
┌──────────────────────────┐
│  Step 3: RuleEngine          │  Deterministic priority table →
│                              │  InterventionAction
└──────────────────────────┘
```

Rather than feeding raw numbers to the model, `HRFeatureExtractor` pre-computes semantic labels in Swift (e.g. `"HIGHER THAN EXPECTED for sedentary (essentially at rest)"`). Quantitative reasoning stays in deterministic code; Gemma reasons over the interpreted meaning. This keeps the model's job squarely in natural language inference rather than arithmetic.

### RuleEngine priority table

| Priority | Condition | Action |
|---|---|---|
| 1 | `physicalAnomaly > 0.70` AND `panic < 0.40` | Medical alert — may not be panic |
| 2 | `panic >= 0.90` AND `confidence == high` | Emergency contact sheet |
| 3 | `panic >= 0.75` | Breathing guide → grounding exercise |
| 4 | `panic >= 0.40` | Grounding exercise only |
| 5 | catch-all | No intervention |

---

## State Machine

```
                       ONBOARDING
                           │
                           ▼
           ┌───────────── IDLE ────────────────────────────┐
           │               │ [hrElevationDetected]         │ [directIntervention]
           │ [manualTriage] ▼                               │
           │           WATCHING                             │
           │               │ [elevationSustained]           │
           │               ▼                                │
           │       SILENT_INVITATION ──[userDismissed]──► IDLE
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
                           IDLE
```

---

## Watch + iPhone Division of Labour

| Responsibility | Watch | iPhone |
|---|---|---|
| HR sensor | ✅ | ❌ |
| HealthKit polling | ❌ | ✅ |
| Silent invitation haptic | ✅ | ❌ |
| Silent invitation UI | ✅ | ❌ |
| Vocal Anchor (mic + ASR) | ❌ | ✅ |
| Gemma4 inference | ❌ | ✅ |
| Breathing guide UI | ✅ | ✅ |
| Quick intervention button | ✅ | ✅ |
| Onboarding / Post-episode log | ❌ | ✅ |

---

## Privacy

Zero network calls. HR data is read-only from HealthKit. Episode logs stay in Core Data. Emergency contact is opt-in and defaults to off. ASR uses Apple's offline recognizer.

---

## Running the Project

**Requirements:** Xcode 16+, iOS 17+ device, watchOS 10+ Apple Watch, Gemma4 `.litertlm` model file.

1. Place the model at `Models/gemma-4-E2B-it.litertlm`
2. Run `xcodegen generate` to regenerate the `.xcodeproj`
3. Open `PanicGuard.xcodeproj` in Xcode
4. Build and run on a real device (HealthKit requires physical hardware)

---

## Acknowledgements

- [LiteRTLM-Swift-SDK](https://github.com/lanka-ai-foundation/LiteRTLM-Swift-SDK) — Swift package by Lanka AI Foundation that provides the `LiteRTLM` inference engine used to run Gemma4 on-device. Without this package, integrating LiteRT into a Swift/SwiftUI project would require significant bridging work.
- [Gemma4 (gemma-4-E2B-it-litert-lm)](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/commit/7fa1d78473894f7e736a21d920c3aa80f950c0db#d2h-629657) — Google DeepMind's Gemma4 E2B model quantized for LiteRT by the litert-community, used here as the on-device triage reasoner.

---

## License

Apache 2.0
