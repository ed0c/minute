# Implementation Plan: Silence Auto Stop

**Branch**: `010-silence-auto-stop` | **Date**: 2026-02-15 | **Spec**: [/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/spec.md](spec.md)
**Input**: Feature specification from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Add automatic end-of-meeting handling during active recording: detect sustained silence via RMS, notify the user at 2 minutes of silence that recording will stop in 30 seconds, support a keep-recording action, and notify users when screen context is enabled and the selected shared window is closed.

The implementation keeps UI thin while adding feature logic and state transitions in `MinuteCore`, then wiring notification actions and state updates in `MeetingPipelineViewModel`.

## Technical Context

**Language/Version**: Swift 5.9 (Xcode 15.x)  
**Primary Dependencies**: SwiftUI, AVFoundation, ScreenCaptureKit, UserNotifications, MinuteCore  
**Storage**: Local files only (existing vault outputs and temporary recording session directory), plus session-scoped event history in memory for stop rationale  
**Testing**: Swift Testing in `MinuteCore/Tests/MinuteCoreTests` and app-level tests in `MinuteTests`  
**Target Platform**: macOS 14+ (Apple Silicon focus)  
**Project Type**: Native macOS app (`Minute`) with core logic in Swift package (`MinuteCore`)  
**Performance Goals**: Silence detection and alerting must not introduce visible lag in recording UI; keep warning delivery within 2 seconds of crossing silence threshold  
**Constraints**: Local-only processing, no new outbound network calls, deterministic output contract unchanged (exactly 3 vault files), long-running operations remain cancellable  
**Scale/Scope**: Single-user desktop feature scoped to recording-time behavior (silence auto-stop, keep-recording warning flow, shared-window-closed notification)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included.
- Local-only processing preserved; no outbound network calls beyond model downloads.
- Deterministic Markdown rendering maintained for any note changes.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation).
- Pipeline state machine and cancellation support respected for long-running work.

**Gate evaluation (pre-design)**: PASS

- Output contract: unchanged; feature affects recording lifecycle and notifications only.
- Local-only/privacy: unchanged; all analysis and decisions remain local.
- Determinism: no note-rendering changes are required.
- Tests: new MinuteCore tests required for silence state transitions and stop reasons; app-level tests required for notification action wiring.
- Pipeline/cancellation: new timers and warning countdown must cancel cleanly when recording stops/cancels.

## Project Structure

### Documentation (this feature)

```text
specs/010-silence-auto-stop/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml
└── tasks.md
```

### Source Code (repository root)

```text
Minute/
├── Sources/
│   ├── App/
│   │   └── MinuteApp.swift
│   └── ViewModels/
│       └── MeetingPipelineViewModel.swift

MinuteCore/
├── Sources/MinuteCore/
│   ├── Domain/
│   │   ├── MeetingPipelineTypes.swift
│   │   ├── MinuteError.swift
│   │   └── MicActivityNotifications.swift
│   └── Services/
│       ├── DefaultAudioService.swift
│       ├── MicActivityNotificationCoordinator.swift
│       ├── ScreenContextCaptureService.swift
│       └── ServiceProtocols.swift
└── Tests/MinuteCoreTests/

MinuteTests/
```

**Structure Decision**: Implement silence-detection policy/state, warning timing, and session event reasons in `MinuteCore` and expose minimal control points consumed by `MeetingPipelineViewModel`. Reuse existing notification category setup in `MinuteApp` and extend categories/actions for this feature.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

## Phase 0 — Research (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/research.md](research.md)

Research tasks executed:
- Research RMS-based silence detection strategy for live AVAudio capture levels.
- Research best practices for actionable macOS notifications with fallback when permission is denied.
- Research robust shared-window-closed detection in ScreenCaptureKit-based capture loops.
- Research integration pattern for pipeline-safe countdown timers and cancellation.

## Phase 1 — Design & Contracts (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/data-model.md](data-model.md)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/contracts/openapi.yaml](contracts/openapi.yaml)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/quickstart.md](quickstart.md)

Design focus:
- Add explicit silence-monitor and warning-countdown states with deterministic transitions.
- Introduce keep-recording action contract and stop-reason event recording.
- Add shared-window lifecycle alert model while preserving current screen-context capture flow.

## Phase 1 — Agent Context Update

Run:
- `.specify/scripts/bash/update-agent-context.sh codex`

## Constitution Check (post-design)

- Output contract: unchanged; no extra vault files added.
- Local-only/privacy: preserved; no outbound calls added.
- Determinism: no markdown rendering contract change.
- Tests: design requires test-first additions for silence transitions, countdown cancellation paths, and shared-window-closed notification behavior.
- Pipeline/cancellation: all countdown and detection tasks explicitly modeled as cancelable with recording lifecycle.

**Gate evaluation (post-design)**: PASS

## Phase 2 — Implementation Planning (next step)

Proceed with `/speckit.tasks` to create implementation tasks for:
- Silence monitoring and countdown state machine additions.
- Notification category/action wiring for keep-recording and shared-window-closed alerts.
- Recording-session stop-reason event history and verification tests.
