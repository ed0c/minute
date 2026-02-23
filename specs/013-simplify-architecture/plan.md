# Implementation Plan: Architecture Simplification Refactor

**Branch**: `013-simplify-architecture` | **Date**: 2026-02-23 | **Spec**: [/Users/roblibob/Projects/FLX/Minute/Minute/specs/013-simplify-architecture/spec.md](spec.md)
**Input**: Feature specification from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/013-simplify-architecture/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Refactor the project for navigation clarity and reduced accidental complexity by decomposing oversized mixed-responsibility modules, consolidating duplicated domain logic into single owners, removing dead code paths, and publishing an ownership map plus migration note.

The plan prioritizes behavior parity for recording, processing, notes, settings, and recovery while keeping abstractions shallow and removing temporary scaffolding after migration.

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 15.x), Swift tools 6.2 for `MinuteCore` package  
**Primary Dependencies**: SwiftUI, Combine, AVFoundation, ScreenCaptureKit, UserNotifications, MinuteCore package modules  
**Storage**: Local files (vault outputs and temporary session artifacts) + local preferences in `UserDefaults`  
**Testing**: Swift Testing in `MinuteCore/Tests/MinuteCoreTests` and app-level tests in `MinuteTests`  
**Target Platform**: macOS 14+ (Apple Silicon focus)  
**Project Type**: Native macOS app target (`Minute`) with supporting Swift package modules (`MinuteCore`, `MinuteWhisper`, `MinuteLlama`)  
**Performance Goals**: No regression in recording/processing responsiveness; cancellation behavior for long-running tasks remains immediate from user perspective; contributor navigation time aligns with spec success criteria  
**Constraints**: Preserve local-only processing and three-file output contract; avoid deep abstraction layers; remove dead code and migration scaffolding before completion  
**Scale/Scope**: Refactor-focused work across high-complexity hotspots in view models, core services, shared utilities, and repeated test setup patterns

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included.
- Local-only processing preserved; no outbound network calls beyond model downloads.
- Deterministic Markdown rendering maintained for any note changes.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation).
- Pipeline state machine and cancellation support respected for long-running work.

**Gate evaluation (pre-design)**: PASS

- Output contract: unchanged; this effort restructures ownership and code paths, not vault artifact shape.
- Local-only/privacy: unchanged; no new network behavior is introduced.
- Determinism: markdown/file-contract behavior remains stable; tests/docs are required for any touched boundary behavior.
- Tests: refactor requires updates to affected test suites and fixture consolidation while preserving behavior coverage.
- Pipeline/cancellation: decomposition must keep existing cancellation and state-machine semantics intact.

## Project Structure

### Documentation (this feature)

```text
specs/013-simplify-architecture/
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
│   ├── ViewModels/
│   └── Views/
│       ├── MeetingNotes/
│       ├── Onboarding/
│       ├── Pipeline/
│       └── Settings/

MinuteCore/
├── Sources/
│   ├── MinuteCore/
│   │   ├── Configuration/
│   │   ├── Contracts/
│   │   ├── Domain/
│   │   ├── Pipeline/
│   │   ├── Rendering/
│   │   ├── Services/
│   │   ├── Utilities/
│   │   └── Vault/
│   ├── MinuteLlama/
│   └── MinuteWhisper/
└── Tests/MinuteCoreTests/

MinuteTests/
```

**Structure Decision**: Keep existing app/package split and simplify within those boundaries using direct, domain-owned modules rather than introducing new layering frameworks. Consolidate shared logic in the nearest existing domain owner (`MinuteCore`) and keep app target modules focused on presentation wiring.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

## Phase 0 — Research (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/013-simplify-architecture/research.md](research.md)

Research tasks executed:
- Define decomposition strategy for oversized mixed-responsibility modules without adding abstraction layers.
- Define consolidation strategy for duplicated logic and utility normalization.
- Define dead-code identification/removal policy with parity safeguards.
- Define migration sequencing and documentation approach that preserves contributor navigability.

## Phase 1 — Design & Contracts (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/013-simplify-architecture/data-model.md](data-model.md)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/013-simplify-architecture/contracts/openapi.yaml](contracts/openapi.yaml)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/013-simplify-architecture/quickstart.md](quickstart.md)

Design focus:
- Define explicit ownership and lifecycle entities for refactor execution.
- Model parity checkpoints so behavior protection is first-class.
- Create abstract contracts for ownership-map publication, consolidation actions, dead-code handling, parity verification, and migration-note publication.

## Phase 1 — Agent Context Update

Run:
- `.specify/scripts/bash/update-agent-context.sh codex`

## Constitution Check (post-design)

- Output contract: unchanged; design artifacts target architecture workflow and documentation boundaries.
- Local-only/privacy: preserved; no added outbound communication.
- Determinism: rendering/contract determinism explicitly retained as gated parity checkpoints.
- Tests: design requires targeted test updates plus fixture consolidation for repeated setup patterns.
- Pipeline/cancellation: parity checkpoints require cancellation/state behavior verification before completion.

**Gate evaluation (post-design)**: PASS

## Phase 2 — Implementation Planning (next step)

Proceed with `/speckit.tasks` to create implementation tasks grouped by:
- Ownership-map definition and hotspot decomposition.
- Shared behavior consolidation and utility centralization.
- Dead-code removal with parity checkpoint validation.
- Test fixture consolidation and migration-note publication.
