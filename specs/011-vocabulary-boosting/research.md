# Research: Vocabulary Boosting Controls

## Decision 1: Upgrade FluidAudio dependency before feature rollout

- Decision: Upgrade the `FluidAudio` package in `MinuteCore/Package.swift` to the latest stable release available at implementation time, and commit the corresponding lockfile update.
- Rationale: The feature explicitly depends on vocabulary boosting support and required CTC vocabulary model handling; pinning to the latest stable release reduces compatibility drift while keeping builds reproducible.
- Alternatives considered:
  - Keep current version (`from: 0.10.0`) and defer upgrade: rejected because it may not include complete vocabulary boosting behavior.
  - Upgrade to a prerelease build: rejected for release-risk and reproducibility concerns.

## Decision 2: Keep vocabulary controls backend-aware with strict gating

- Decision: Show global and per-session vocabulary controls only when transcription backend is FluidAudio; hide/disable controls for Whisper while preserving already-saved global settings.
- Rationale: This aligns UX with actual capability and avoids non-functional controls that cause confusion.
- Alternatives considered:
  - Always show controls with explanatory text: rejected because it increases UI clutter and support burden.
  - Remove saved settings when backend changes: rejected because it discards user intent and creates unnecessary setup churn.

## Decision 3: Missing vocabulary models must not block recording

- Decision: If required vocabulary models are missing when recording starts, allow recording to start, disable vocabulary boosting for that session, and surface a clear warning/status.
- Rationale: Recording continuity is higher priority than optional boost behavior; this prevents meeting loss while still exposing actionable status.
- Alternatives considered:
  - Hard-block session start: rejected because it interrupts user workflow during time-sensitive meetings.
  - Force immediate model download prompt: rejected because it introduces a blocking branch and added failure modes.

## Decision 4: Session Custom mode is additive over global terms

- Decision: In `Custom` mode, effective terms are `Global + Session Custom` for that session; empty custom input falls back to `Default` behavior.
- Rationale: This preserves reusable baseline terms while enabling meeting-specific additions with minimal user effort.
- Alternatives considered:
  - Replace global terms with custom terms: rejected because users can unintentionally lose baseline recognition.
  - Treat empty custom as Off: rejected because behavior becomes surprising and harder to predict.

## Decision 5: Normalize vocabulary input deterministically

- Decision: Parse comma/newline-separated terms, trim surrounding whitespace, remove blank entries, and deduplicate case-insensitively while preserving first-entered order and display casing.
- Rationale: Deterministic normalization avoids duplicate boost entries and keeps visible term lists stable for users.
- Alternatives considered:
  - Preserve raw input without dedupe: rejected due to noisy duplicates and unstable behavior.
  - Alphabetically sort normalized terms: rejected because it loses user-entered ordering context.

## Decision 6: Keep business logic in MinuteCore; UI remains thin

- Decision: Place vocabulary policy/state, normalization, and readiness mapping in `MinuteCore`; keep SwiftUI views focused on control rendering and user interactions.
- Rationale: Matches repository architecture and constitution principles, and enables deterministic unit tests.
- Alternatives considered:
  - Put normalization and policy logic directly in views/view-models: rejected due to lower testability and higher coupling.

## Decision 7: Test-first coverage for policy and contracts

- Decision: Add/extend test coverage in `MinuteCore/Tests/MinuteCoreTests` for normalization, mode resolution (`Off`/`Default`/`Custom`), and missing-model fallback semantics, plus app-level tests for backend gating and control visibility.
- Rationale: Constitution requires test-gated core behavior and deterministic validation of contract-impacting logic.
- Alternatives considered:
  - UI-only tests without core tests: rejected because core policy regressions would be under-detected.

## Resolved Clarifications

All planning-stage ambiguities for this feature are resolved; no `NEEDS CLARIFICATION` items remain.
