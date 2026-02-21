# Research: Settings Information Architecture Refresh

## Decision 1: Keep settings inside the existing app window via workspace routing

- Decision: Use single-window workspace routing where `pipeline` and `settings` are peer full-window workspaces in the same main window.
- Rationale: This directly satisfies the requirement to avoid additional app windows and eliminates modal/overlay behavior.
- Alternatives considered:
  - Open settings in a second window: rejected because it violates the single-window requirement.
  - Keep current overlay/panel model: rejected because it does not deliver a true full-window settings workspace.

## Decision 2: Preserve recording/work continuity by decoupling runtime state from workspace visibility

- Decision: Ensure recording/pipeline runtime state is owned by long-lived app-scoped state (not tied to whether the pipeline workspace is currently visible).
- Rationale: Switching between `pipeline` and `settings` must not pause/cancel/reset active recording or in-progress session work.
- Alternatives considered:
  - Recreate pipeline state when leaving settings: rejected due to disruption risk and possible data loss.
  - Auto-stop recording when opening settings: rejected because it conflicts with explicit continuity requirements.

## Decision 3: Use stable, task-oriented settings categories with explicit metadata

- Decision: Represent categories as metadata-driven navigation items (id, title, order, visibility rule, destination content).
- Rationale: A metadata-driven category model scales better as settings grow and keeps sidebar organization predictable.
- Alternatives considered:
  - Hard-code category ordering across multiple views: rejected due to higher maintenance cost and drift risk.
  - Create categories dynamically from sections at runtime without explicit ordering: rejected because ordering/discoverability becomes unstable.

## Decision 4: Preserve existing setting locations while improving discoverability incrementally

- Decision: Reorganize existing settings into clearer top-level categories without removing any option; prioritize recognizable naming and shallow navigation.
- Rationale: Users must retain access to all current settings while benefiting from improved findability.
- Alternatives considered:
  - Large taxonomy rewrite with deep nesting: rejected for higher relearning cost and migration risk.
  - Leave organization unchanged and only resize container: rejected because it does not address discoverability.

## Decision 5: Accessibility and keyboard navigation are first-class for sidebar + detail area

- Decision: Sidebar category selection and main settings content must support keyboard focus order, semantic labels, and predictable navigation.
- Rationale: The settings workspace is a high-frequency task area and must remain operable without pointer input.
- Alternatives considered:
  - Defer accessibility until after layout refactor: rejected because it creates regressions and rework risk.

## Decision 6: Add explicit continuity regression coverage in both app and core test layers

- Decision: Add app-level tests for workspace routing and continuity behavior, and add/update MinuteCore non-regression tests that assert pipeline state changes only via pipeline events.
- Rationale: Constitution requires test-gated behavior with deterministic guarantees; continuity is a critical acceptance condition.
- Alternatives considered:
  - UI-only snapshot checks: rejected because they do not validate runtime continuity behavior.
  - Manual QA only: rejected because regressions would be too easy to miss.

## Resolved Clarifications

All planning-stage unknowns for this feature are resolved. No `NEEDS CLARIFICATION` markers remain.
