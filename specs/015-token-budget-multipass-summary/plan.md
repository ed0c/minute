# Implementation Plan: Token Budget and Multi-Pass Summarization

**Branch**: `015-token-budget-multipass-summary` | **Date**: 2026-03-06 | **Spec**: [/Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/spec.md](spec.md)
**Input**: Feature specification from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Add deterministic token-budget preflight and multi-pass summarization so long transcripts are processed safely without llama Metal aborts, while progressively updating the same meeting summary document after each valid pass.

The approach introduces pass planning, checkpointed summary state, retry-from-last-valid behavior, a deterministic pass-delta merge path, and a hardware-aware context window setting that preserves the existing output contract and pipeline cancellation semantics.
Keep the visible preflight cheap and heuristic, but derive its context window from the same user-selected preset used at runtime; then refine the pass plan with the runtime tokenizer after the llama model is loaded and reuse that loaded model for the subsequent pass executions.

## Technical Context

**Language/Version**: Swift 5.9+ (Xcode 15.x), Swift tools 6.2 for `MinuteCore` package  
**Primary Dependencies**: SwiftUI, Combine, MinuteCore pipeline/services, MinuteLlama summarization service, OSLog  
**Storage**: Local files (vault outputs and temporary session artifacts) + local preferences in `UserDefaults` where already used  
**Testing**: Swift Testing in `MinuteCore/Tests/MinuteCoreTests` and app-level tests in `MinuteTests`  
**Target Platform**: macOS 14+ (Apple Silicon focus)  
**Project Type**: Native macOS app target (`Minute`) with Swift package modules (`MinuteCore`, `MinuteLlama`, `MinuteWhisperService`)  
**Performance Goals**: Preflight budget/pass estimate visible before run; long transcripts complete without process abort; progressive pass updates remain responsive and cancellable; runtime pass refinement must avoid a second model startup  
**Constraints**: Local-only processing, unchanged three-file vault contract, deterministic rendering/writes, no raw transcript logging by default  
**Scale/Scope**: Summarization pipeline behavior, pass planning state, context-window settings/onboarding defaults, progress reporting, retry semantics, and associated tests/docs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Output contract unchanged or updated docs/tests included.
- Local-only processing preserved; no outbound network calls beyond model downloads.
- Deterministic Markdown rendering maintained for any note changes.
- MinuteCore tests added/updated for new behavior (renderer, file contracts, JSON validation).
- Pipeline state machine and cancellation support respected for long-running work.

**Gate evaluation (pre-design)**: PASS

- Output contract: unchanged, feature affects summarization execution strategy and progress checkpoints only.
- Local-only/privacy: preserved; no new network activity.
- Determinism: preserved via valid-pass checkpointing and atomic updates.
- Tests: required additions for budgeting, chunking, merge/checkpoint behavior, and retry state.
- Pipeline/cancellation: preserved by keeping work in existing coordinator state machine and cancellation checks.

## Project Structure

### Documentation (this feature)

```text
specs/015-token-budget-multipass-summary/
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
└── Sources/
    └── ViewModels/

MinuteCore/
├── Sources/
│   ├── MinuteCore/
│   │   ├── Pipeline/
│   │   ├── Services/
│   │   ├── Domain/
│   │   └── Rendering/
│   └── MinuteLlama/
│       └── Services/
└── Tests/
    └── MinuteCoreTests/

MinuteTests/
```

**Structure Decision**: Implement budgeting/pass orchestration in `MinuteCore` pipeline and llama service boundaries; keep UI surface changes in existing `Minute` view models/presenters with no new top-level modules.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |

## Phase 0 — Research (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/research.md](research.md)

Research tasks executed:
- Research conservative token budget derivation and runtime reserve strategy for local llama summarization.
- Research chunking/merge patterns for progressive summarization with deterministic outputs.
- Research checkpoint/retry behavior for partial-progress preservation.
- Research progress estimate drift handling between preflight and runtime.

## Phase 1 — Design & Contracts (complete)

Outputs:
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/data-model.md](data-model.md)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/contracts/openapi.yaml](contracts/openapi.yaml)
- [/Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/quickstart.md](quickstart.md)

Design focus:
- Define token-budget estimate, pass plan, pass checkpoint, and resumable run entities.
- Define contract-level behavior for preflight, pass execution, status, and resume.
- Define a chunk-local pass-delta schema and deterministic in-app merge rules so later passes update canonical sections instead of rewriting the whole summary.
- Define a hardware-aware context-window preference shared by onboarding, AI settings, preflight estimation, and runtime summarization.

## Phase 1 — Agent Context Update

Run:
- `.specify/scripts/bash/update-agent-context.sh codex`

## Constitution Check (post-design)

- Output contract: unchanged; design artifacts preserve note/audio/transcript contract and update behavior only.
- Local-only/privacy: preserved; contracts are local workflow contracts and do not introduce outbound calls.
- Determinism: maintained through explicit pass-delta merge/checkpoint rules and atomic summary updates.
- Tests: plan includes expanded MinuteCore tests for budgeting/chunking/merge/retry and pipeline progress states.
- Pipeline/cancellation: design keeps existing pipeline state machine and requires cancellation-safe pass boundaries.
- Runtime refinement: supported by keeping model-aware chunk planning inside the summarization runtime boundary so token accuracy does not add separate startup latency.
- Context-window alignment: preflight and runtime share the same effective context selection so the estimate users see before a run matches the selected AI configuration.

**Gate evaluation (post-design)**: PASS

## Phase 2 — Implementation Planning (next step)

Proceed with `/speckit.tasks` to create implementation tasks grouped by:
- Budget preflight and pass planning.
- Multi-pass execution and checkpointed summary updates.
- Resume/retry behavior and failure containment.
- Pipeline/UI status updates and test coverage expansion.
