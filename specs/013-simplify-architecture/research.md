# Phase 0 Research: Architecture Simplification Refactor

## Research Task 1: Decompose Oversized Modules Without Multi-Layer Abstractions

**Decision**: Decompose oversized modules by workflow responsibility (session lifecycle, status presentation, note loading/editing, model-setup lifecycle) and keep one orchestration entry point per workflow.

**Rationale**: The goal is easier navigation, so contributors need clear ownership boundaries while preserving direct call paths. This keeps architecture shallow and discoverable.

**Alternatives considered**:
- Introduce generic abstraction frameworks for all workflows: rejected because this increases indirection and harms navigability.
- Keep large files and rely on comments/regions only: rejected because logical boundaries remain unclear and coupling persists.

## Research Task 2: Consolidate Duplicated Logic Into Single Domain Owners

**Decision**: Consolidate duplicated path normalization, defaults observation, and shared capture/wrapper behavior into canonical domain owners in `MinuteCore`, with app-layer modules consuming them directly.

**Rationale**: Duplication is a key source of accidental complexity and inconsistent behavior. Canonical ownership reduces edit scatter and behavioral drift.

**Alternatives considered**:
- Leave duplicates and enforce consistency via review checklists: rejected because manual consistency does not scale.
- Create multiple adapters around duplicated logic per feature area: rejected because it preserves duplication under new names.

## Research Task 3: Dead Code Identification and Safe Removal Policy

**Decision**: Treat code as removable only when it is unreachable, unused, or replaced by a canonical owner, and require parity checks for critical user flows before/after deletion.

**Rationale**: The feature requires no dead code, but removals must not regress behavior. Pairing deletion with parity checkpoints prevents accidental loss of edge-path behavior.

**Alternatives considered**:
- Defer dead code removal until after refactor completion: rejected because stale code remains and confuses ownership during migration.
- Remove aggressively without parity checkpoints: rejected due to regression risk in recording/recovery/cancellation paths.

## Research Task 4: Behavior Parity During Incremental Refactor

**Decision**: Use incremental vertical slices, each ending with explicit parity checkpoints for recording, processing, note browsing/editing, settings/model setup, and recovery/cancellation semantics.

**Rationale**: Refactoring high-coupling areas safely requires frequent validation. Vertical slices keep changes reviewable and isolate rollback scope.

**Alternatives considered**:
- Big-bang refactor in one merge: rejected because risk concentration is too high.
- Refactor-only branch with delayed tests: rejected because breakages surface too late.

## Research Task 5: Documentation Strategy for Navigability

**Decision**: Produce and maintain an Ownership Map and Refactor Migration Note as first-class artifacts, updated in lockstep with code moves and deletions.

**Rationale**: The specification explicitly targets understandability and navigation; static code changes alone are insufficient without updated contributor guidance.

**Alternatives considered**:
- Rely solely on commit history: rejected because it is not an efficient navigation aid.
- Add extensive inline comments instead of ownership docs: rejected because comments drift and can obscure code intent.

## Research Task 6: Test Structure Simplification

**Decision**: Introduce shared fixture builders for repeated heavy setup in high-volume test suites, while preserving explicit scenario intent in each test.

**Rationale**: Repeated setup contributes to noise and maintenance overhead. Shared fixtures improve readability and lower friction for adding parity tests.

**Alternatives considered**:
- Keep duplicated test setup for explicitness: rejected because repetition obscures scenario intent.
- Centralize all assertions into helper methods: rejected because this hides behavior expectations.
