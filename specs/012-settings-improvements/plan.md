# Implementation Plan: Settings Information Architecture Refresh

**Branch**: `012-settings-improvements` | **Date**: 2026-02-21 | **Spec**: [/Users/roblibob/Projects/FLX/Minute/Minute/specs/012-settings-improvements/spec.md](spec.md)
**Input**: Feature specification from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/012-settings-improvements/spec.md`

## Summary

Refactor settings into a dedicated full-window workspace inside the existing main application window, with category navigation in a sidebar and details in the main pane. Keep the app strictly single-window for this flow and preserve active recording/in-progress work continuity when switching between pipeline and settings workspaces.

## Technical Context

**Language/Version**: Swift (SwiftUI app target, Swift package modules)  
**Primary Dependencies**: SwiftUI, AppKit, Combine, MinuteCore, existing settings view models/services  
**Storage**: Existing local settings persistence (`UserDefaults` + local file-backed app state where already used); no new storage systems  
**Testing**: Swift Testing/XCTest via `xcodebuild` in `MinuteTests` and `MinuteCore/Tests/MinuteCoreTests`  
**Target Platform**: macOS 14+ (native macOS app)  
**Project Type**: Monorepo native macOS app (`Minute`) + shared package (`MinuteCore`)  
**Performance Goals**: Category switch render in under 1 second for >=95% of interactions; no user-visible lag when opening/closing settings  
**Constraints**: Single-window routing only, no settings overlay, no new app windows, active recording/work continuity must be preserved, local-only processing guarantees preserved  
**Scale/Scope**: Existing settings domains reorganized into scalable sidebar categories, with room for future category growth

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included.
- Local-only processing preserved; no outbound network calls beyond model downloads.
- Deterministic Markdown rendering maintained for any note changes.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation).
- Pipeline state machine and cancellation support respected for long-running work.

**Gate evaluation (pre-design)**: PASS

- Output contract: unchanged (settings IA/routing only; no vault path/note format changes).
- Local-only/privacy: unchanged; no new network behavior introduced.
- Determinism: Markdown/output rendering unchanged by planned scope.
- Tests: implementation plan includes app-level routing/continuity tests and MinuteCore non-regression updates for pipeline invariants.
- Pipeline/cancellation: continuity constraints explicitly protect active recording and session progress during workspace switching.

## Project Structure

### Documentation (this feature)

```text
specs/012-settings-improvements/
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
├── AppNavigationModel.swift
├── Sources/Views/ContentView.swift
├── Sources/Views/Settings/
│   ├── MainSettingsView.swift
│   ├── SettingsOverlayView.swift
│   ├── SettingsView.swift
│   └── ...
└── Sources/Views/Pipeline/
    └── PipelineContentView.swift

MinuteCore/
├── Sources/MinuteCore/
│   ├── Domain/
│   ├── Pipeline/
│   └── Services/
└── Tests/MinuteCoreTests/

MinuteTests/
```

**Structure Decision**: Keep workspace routing + settings IA rendering in `Minute` UI/view-model layers, while preserving pipeline continuity contracts with supporting non-regression coverage in `MinuteCore` tests.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

## Phase 0 — Research (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/012-settings-improvements/research.md](research.md)

Research tasks executed:
- Research single-window workspace routing patterns for settings transitions.
- Research continuity-safe lifecycle ownership for recording/pipeline state during workspace switches.
- Research scalable sidebar category metadata patterns for long-term settings growth.
- Research accessibility and keyboard-navigation best practices for sidebar/detail settings layouts.

## Phase 1 — Design & Contracts (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/012-settings-improvements/data-model.md](data-model.md)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/012-settings-improvements/contracts/openapi.yaml](contracts/openapi.yaml)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/012-settings-improvements/quickstart.md](quickstart.md)

Design focus:
- Model single-window workspace routing, settings category metadata, and continuity invariants as explicit entities.
- Define a contract surface for workspace switching and category selection with continuity guarantees.
- Define implementation quickstart focused on non-disruptive routing and scalable category organization.

## Phase 1 — Agent Context Update

Run:
- `.specify/scripts/bash/update-agent-context.sh codex`

## Constitution Check (post-design)

- Output contract: unchanged by design artifacts.
- Local-only/privacy: preserved; no network or data-flow changes introduced.
- Determinism: no note rendering contract changes; continuity invariants explicitly captured.
- Tests: plan requires app and core non-regression tests for routing continuity and state preservation.
- Pipeline/cancellation: workspace transitions explicitly constrained to avoid interruption/reset of active recording/work.

**Gate evaluation (post-design)**: PASS

## Phase 2 — Implementation Planning (next step)

Proceed with `/speckit.tasks` to generate implementation tasks for:
- single-window settings workspace routing replacement,
- non-disruptive continuity behavior while recording/in-progress work,
- sidebar category metadata and discoverability reorganization,
- accessibility/keyboard interaction verification,
- test-first coverage across app and core non-regression suites.
