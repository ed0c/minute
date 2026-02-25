# Implementation Plan: Custom Meeting Prompt Authoring

**Branch**: `014-custom-meeting-prompts` | **Date**: 2026-02-23 | **Spec**: [/Users/roblibob/Projects/FLX/Minute/Minute/specs/014-custom-meeting-prompts/spec.md](spec.md)
**Input**: Feature specification from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/014-custom-meeting-prompts/spec.md`

## Summary

Enable a user-managed meeting prompt library that supports both custom meeting types and editable built-in prompts, then wire it into the existing two-pass processing flow so classifier output and summarization inference both resolve through the same prompt definition source.

The plan introduces a structured prompt-component model (instead of only hardcoded strategy strings), a dedicated "Meeting Types" settings section for authoring those components, and an end-to-end selection/classification/inference resolution path that remains local-only and preserves the current output contract.

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 15.x), Swift tools 6.2 (`MinuteCore`)  
**Primary Dependencies**: SwiftUI, Combine, MinuteCore pipeline/services, MinuteLlama summarization service, existing UserDefaults-backed settings stores  
**Storage**: Local-only persistence via `UserDefaults` (+ optional local JSON snapshot for prompt library migrations if needed); existing vault outputs remain unchanged  
**Testing**: Swift Testing in `MinuteCore/Tests/MinuteCoreTests` + app/UI integration tests in `MinuteTests` (where applicable)  
**Target Platform**: Native macOS 14+ app  
**Project Type**: Single macOS app target (`Minute`) with shared package modules (`MinuteCore`, `MinuteLlama`)  
**Performance Goals**: Prompt resolution and meeting-type selection should feel immediate (<100 ms local resolution per interaction); classifier pass should remain bounded and keep existing summarization responsiveness expectations  
**Constraints**: Local-only processing; no outbound network calls except model downloads; deterministic note output contract remains stable; long-running operations stay cancellable; no extra vault artifacts beyond existing 3-file contract  
**Scale/Scope**: Support built-in prompt overrides plus user-defined custom types (target: at least dozens of types without degrading settings usability), and preserve compatibility for existing meetings/preferences

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included.
- Local-only processing preserved; no outbound network calls beyond model downloads.
- Deterministic Markdown rendering maintained for any note changes.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation).
- Pipeline state machine and cancellation support respected for long-running work.

**Gate evaluation (pre-design)**: PASS

- Output contract: prompt customization only; no intended change to three-file vault contract.
- Local-only/privacy: all prompt authoring, classification, and inference remain local.
- Determinism: rendering path stays deterministic; only prompt selection logic changes.
- Tests: plan includes new MinuteCore tests for prompt composition, selection fallback, classifier label resolution, and persistence migration behavior.
- Pipeline/cancellation: custom prompt resolution is synchronous/local and does not alter coordinator cancellation semantics.

## Project Structure

### Documentation (this feature)

```text
/Users/roblibob/Projects/FLX/Minute/Minute/specs/014-custom-meeting-prompts/
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
/Users/roblibob/Projects/FLX/Minute/Minute/Minute/
├── Sources/ViewModels/
│   └── MeetingPipelineViewModel.swift
├── Sources/Views/Pipeline/Stage/
│   └── SessionViews.swift
└── Sources/Views/Settings/
    ├── SettingsCategoryCatalog.swift
    ├── MainSettingsView.swift
    └── [new meeting-types settings section/view model files]

/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/
├── Sources/MinuteCore/
│   ├── Domain/
│   │   ├── MeetingType.swift
│   │   ├── StagePreferences.swift
│   │   └── [new prompt-library domain entities]
│   ├── Services/
│   │   ├── StagePreferencesStore.swift
│   │   ├── ServiceProtocols.swift
│   │   └── [new prompt-library store/resolver services]
│   ├── Summarization/
│   │   ├── Prompts/PromptFactory.swift
│   │   ├── Prompts/Strategies/*.swift
│   │   └── Services/MeetingTypeClassifier.swift
│   └── Pipeline/
│       ├── PipelineTypes.swift
│       └── MeetingPipelineCoordinator.swift
└── Tests/MinuteCoreTests/
    ├── Summarization/
    └── [new prompt-library persistence/composition/resolution tests]

/Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLlama/
└── Services/LlamaLibrarySummarizationService.swift
```

**Structure Decision**: Keep UI authoring in `Minute` (dedicated Settings "Meeting Types" section + stage controls) and move prompt-library business logic, classifier resolution, and inference prompt composition into `MinuteCore`/`MinuteLlama` so pipeline behavior stays testable and deterministic.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

## Phase 0 — Research (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/014-custom-meeting-prompts/research.md](research.md)

Research tasks executed:
- Define full prompt-component boundaries that reach inference (system + user prompt composition).
- Define a dedicated Settings "Meeting Types" authoring model for users to create/edit prompt parts safely.
- Define classifier strategy for custom meeting types with conservative fallback behavior.
- Define end-to-end pipeline flow from selection/autodetect to effective prompt resolution.
- Define persistence/migration strategy from current enum-based meeting type preferences.

## Phase 1 — Design & Contracts (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/014-custom-meeting-prompts/data-model.md](data-model.md)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/014-custom-meeting-prompts/contracts/openapi.yaml](contracts/openapi.yaml)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/014-custom-meeting-prompts/quickstart.md](quickstart.md)

Design focus:
- Model prompt-library entities (built-in definitions, overrides, custom meeting types, classifier profiles, resolved prompt bundles).
- Define stable contracts for prompt-library CRUD, built-in override restore, classifier resolution, and inference prompt resolution.
- Define implementation sequence that preserves existing meeting processing while migrating to custom-capable selection identifiers.

## Phase 1 — Agent Context Update

Run:
- `.specify/scripts/bash/update-agent-context.sh codex`

## Constitution Check (post-design)

- Output contract: unchanged by design; note/transcript/audio paths and markdown contract remain intact.
- Local-only/privacy: preserved; prompt authoring/classification/inference are local and use existing model execution path.
- Determinism: design introduces deterministic prompt assembly order and explicit fallback rules.
- Tests: design requires MinuteCore unit coverage for prompt composition, meeting-type resolution, classifier label mapping, and persistence migration.
- Pipeline/cancellation: prompt resolution is lightweight and synchronous; no new long-running uncancellable stages added.

**Gate evaluation (post-design)**: PASS

## Phase 2 — Implementation Planning (next step)

Proceed with `/speckit.tasks` to generate implementation tasks for:
- prompt-library domain and persistence,
- dedicated Settings "Meeting Types" UI for prompt components and built-in overrides,
- stage selection + autodetect integration with custom type IDs,
- summarization prompt composition refactor and classifier label expansion,
- regression coverage for output contract, fallback behavior, and migration compatibility.
