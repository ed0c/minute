# Implementation Plan: Vocabulary Boosting Controls

**Branch**: `011-vocabulary-boosting` | **Date**: 2026-02-18 | **Spec**: [/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/spec.md](spec.md)
**Input**: Feature specification from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/spec.md`

## Summary

Add vocabulary boosting controls for FluidAudio only: global settings in AI Models (enable toggle, multi-term editor, strength selector), per-session override modes (Off/Default/Custom), backend-aware gating for Whisper, and inline readiness feedback when required vocabulary models are missing. Complete Step 0 by upgrading the FluidAudio package first, then implement deterministic term normalization and session policy rules in `MinuteCore` with thin SwiftUI integration.

## Technical Context

**Language/Version**: Swift (SwiftUI app target + Swift tools 6.2 package)  
**Primary Dependencies**: SwiftUI, MinuteCore, FluidAudio, OSLog, existing model manager/status components  
**Storage**: Local app settings persistence for global vocabulary config + session-scoped in-memory override state; no new vault output files  
**Testing**: Swift Testing in `MinuteCore/Tests/MinuteCoreTests` and app-level tests in `MinuteTests`  
**Target Platform**: macOS 14+ (native macOS app)  
**Project Type**: Monorepo native app (`Minute`) with shared Swift package core (`MinuteCore`)  
**Performance Goals**: No visible lag in settings/session controls; vocabulary mode evaluation performed synchronously with user action and recording start flow  
**Constraints**: Local-only processing, no outbound network calls except model downloads, deterministic policy for term parsing/effective mode, pipeline cancellation behavior preserved  
**Scale/Scope**: Single-user desktop flow; feature scoped to settings/session configuration and transcription behavior toggling

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included.
- Local-only processing preserved; no outbound network calls beyond model downloads.
- Deterministic Markdown rendering maintained for any note changes.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation).
- Pipeline state machine and cancellation support respected for long-running work.

**Gate evaluation (pre-design)**: PASS

- Output contract: unchanged (no additional meeting artifacts; no vault path change).
- Local-only/privacy: preserved; feature only affects local settings/session control and local model readiness state.
- Determinism: note rendering unchanged; vocabulary policy decisions explicitly deterministic.
- Tests: plan requires new/updated MinuteCore and app tests for policy resolution and UI gating.
- Pipeline/cancellation: recording start remains non-blocking when vocabulary models are missing; no new uncancelable long-running operations.

## Project Structure

### Documentation (this feature)

```text
specs/011-vocabulary-boosting/
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
│   ├── Views/Settings/
│   │   ├── ModelsSettingsSection.swift
│   │   └── ModelsSettingsViewModel.swift
│   ├── Views/Pipeline/Stage/
│   │   └── SessionViews.swift
│   └── ViewModels/
│       └── MeetingPipelineViewModel.swift

MinuteCore/
├── Package.swift
├── Sources/MinuteCore/
│   ├── Domain/
│   ├── Services/
│   └── Configuration/
└── Tests/MinuteCoreTests/

MinuteTests/
```

**Structure Decision**: Keep business logic (term normalization, effective mode resolution, readiness fallback policy) in `MinuteCore`; use `Minute` view/view-model layers only to render controls, collect user input, and dispatch configuration updates.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

## Phase 0 — Research (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/research.md](research.md)

Research tasks executed:
- Research dependency-upgrade approach for FluidAudio vocabulary support.
- Research deterministic normalization policy for term lists.
- Research integration pattern for backend-aware gating and model-readiness handling.
- Research session override behavior patterns that minimize user confusion and prevent settings loss.

## Phase 1 — Design & Contracts (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/data-model.md](data-model.md)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/contracts/openapi.yaml](contracts/openapi.yaml)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/quickstart.md](quickstart.md)

Design focus:
- Model global configuration, session override, readiness status, and normalized terms as explicit entities with validation rules.
- Define deterministic effective-mode resolution, including empty-custom fallback and additive custom terms.
- Define a contract surface for settings/session vocabulary operations that supports testable, stable behavior.

## Phase 1 — Agent Context Update

Run:
- `.specify/scripts/bash/update-agent-context.sh codex`

## Constitution Check (post-design)

- Output contract: unchanged by design artifacts; implementation is constrained to settings/session behavior.
- Local-only/privacy: preserved; only local settings/state and model availability are involved.
- Determinism: normalization and effective-mode rules are explicitly deterministic in data model and contract.
- Tests: plan requires test-first additions in `MinuteCore` and app test targets before implementation completion.
- Pipeline/cancellation: policy explicitly allows non-blocking session start when vocab models are missing.

**Gate evaluation (post-design)**: PASS

## Phase 2 — Implementation Planning (next step)

Proceed with `/speckit.tasks` to generate implementation tasks for:
- FluidAudio dependency upgrade and compatibility checks.
- Global vocabulary settings UI + persistence + readiness status row.
- Session vocabulary override row/popover and effective-mode resolution.
- Deterministic normalization utilities and coverage tests.
