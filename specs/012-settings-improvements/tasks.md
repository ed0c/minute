# Tasks: Settings Information Architecture Refresh

**Input**: Design documents from `/specs/012-settings-improvements/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are REQUIRED for this feature per constitution and quickstart (test-first coverage for routing, continuity, and category organization).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create shared scaffolding for implementation and tests.

- [X] T001 Create settings workspace test support scaffolding in `MinuteTests/TestSupport/SettingsWorkspaceTestSupport.swift`
- [X] T002 [P] Create continuity fixture support for core tests in `MinuteCore/Tests/MinuteCoreTests/TestSupport/WorkspaceContinuityFixtures.swift`
- [X] T003 [P] Create settings category metadata scaffold in `Minute/Sources/Views/Settings/SettingsCategoryCatalog.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core primitives required before any user story implementation.

**⚠️ CRITICAL**: No user story work should begin until this phase is complete.

- [X] T004 Implement workspace route primitives and idempotent route API in `Minute/AppNavigationModel.swift`
- [X] T005 Implement continuity snapshot model and invariant checks in `MinuteCore/Sources/MinuteCore/Domain/WorkspaceContinuityInvariant.swift`
- [X] T006 [P] Add MinuteCore invariants test coverage in `MinuteCore/Tests/MinuteCoreTests/WorkspaceContinuityInvariantTests.swift`
- [X] T007 Implement shared category definition types (id/title/order/visibility) in `Minute/Sources/Views/Settings/SettingsCategoryCatalog.swift`
- [X] T008 Wire baseline category selection state container in `Minute/Sources/Views/Settings/MainSettingsView.swift`

**Checkpoint**: Foundation ready - user stories can now be implemented.

---

## Phase 3: User Story 1 - Open Settings in the Existing Main Window (Priority: P1) 🎯 MVP

**Goal**: Replace overlay settings with a full-window settings workspace in the same app window while preserving ongoing recording/work.

**Independent Test**: Open settings from the app menu and verify the same window switches between pipeline/settings without creating a second window; while recording or processing, switching in/out of settings does not interrupt state.

### Tests for User Story 1 (REQUIRED) ⚠️

- [X] T009 [P] [US1] Add single-window routing tests in `MinuteTests/SettingsWorkspaceRoutingTests.swift`
- [X] T010 [P] [US1] Add recording/work continuity tests for workspace switching in `MinuteTests/SettingsWorkspaceContinuityTests.swift`
- [X] T011 [US1] Add contract-alignment tests for workspace state semantics in `MinuteTests/SettingsWorkspaceContractTests.swift`

### Implementation for User Story 1

- [X] T012 [US1] Replace overlay composition with route-based full-window composition in `Minute/Sources/Views/ContentView.swift`
- [X] T013 [US1] Keep Settings command routed to existing window workspace in `Minute/Sources/App/MinuteApp.swift`
- [X] T014 [US1] Implement idempotent `pipeline/settings` transition logic in `Minute/AppNavigationModel.swift`
- [X] T015 [US1] Update settings close behavior to return to pipeline workspace in `Minute/Sources/Views/Settings/MainSettingsView.swift`
- [X] T016 [US1] Remove obsolete overlay behavior from `Minute/Sources/Views/Settings/SettingsOverlayView.swift`
- [X] T017 [US1] Preserve active session/recording state across workspace switches in `Minute/Sources/ViewModels/MeetingPipelineViewModel.swift`
- [X] T018 [US1] Ensure pipeline UI state restoration after returning from settings in `Minute/Sources/Views/Pipeline/PipelineContentView.swift`

**Checkpoint**: User Story 1 is independently functional and testable (MVP).

---

## Phase 4: User Story 2 - Find Settings Quickly by Category (Priority: P2)

**Goal**: Improve settings discoverability with clear, task-oriented sidebar categories and complete setting reachability.

**Independent Test**: From settings workspace, users can navigate category labels in the sidebar and reach all existing settings via logically grouped sections.

### Tests for User Story 2 (REQUIRED) ⚠️

- [X] T019 [P] [US2] Add category ordering/discoverability tests in `MinuteTests/SettingsCategoryCatalogTests.swift`
- [X] T020 [P] [US2] Add setting reachability mapping tests for all existing settings sections in `MinuteTests/SettingsSectionReachabilityTests.swift`
- [X] T021 [US2] Update updater-dependent category visibility regression tests in `MinuteTests/UpdaterProfileBehaviorTests.swift`

### Implementation for User Story 2

- [X] T022 [US2] Define user-facing category taxonomy and labels in `Minute/Sources/Views/Settings/SettingsCategoryCatalog.swift`
- [X] T023 [US2] Refactor sidebar rendering and detail switching to taxonomy-driven mapping in `Minute/Sources/Views/Settings/MainSettingsView.swift`
- [X] T024 [P] [US2] Reorganize general/workspace group composition in `Minute/Sources/Views/Settings/GeneralSettingsSection.swift`
- [X] T025 [P] [US2] Reorganize AI/model-related group composition in `Minute/Sources/Views/Settings/ModelsSettingsSection.swift`
- [X] T026 [P] [US2] Reorganize privacy/permissions group composition in `Minute/Sources/Views/Settings/PermissionsSettingsSection.swift`
- [X] T027 [P] [US2] Reorganize vault/storage group composition in `Minute/Sources/Views/Settings/VaultConfigurationView.swift`
- [X] T028 [P] [US2] Reorganize speaker/people group composition in `Minute/Sources/Views/Settings/KnownSpeakersSettingsSection.swift`
- [X] T029 [US2] Add keyboard navigation and accessibility labels for category list and detail context in `Minute/Sources/Views/Settings/MainSettingsView.swift`

**Checkpoint**: User Stories 1 and 2 are both independently functional and testable.

---

## Phase 5: User Story 3 - Scale Settings for Future Growth (Priority: P3)

**Goal**: Ensure category model and selection behavior scale safely as more settings/categories are added.

**Independent Test**: Add or hide categories through metadata rules and verify stable ordering, valid fallback selection, and no workflow disruption.

### Tests for User Story 3 (REQUIRED) ⚠️

- [X] T030 [P] [US3] Add category fallback selection tests when visibility changes in `MinuteTests/SettingsCategorySelectionFallbackTests.swift`
- [X] T031 [P] [US3] Add idempotent re-open/no-extra-window regression tests in `MinuteTests/SettingsWorkspaceIdempotencyTests.swift`
- [X] T032 [US3] Add stability tests for category metadata growth behavior in `MinuteTests/SettingsCategoryGrowthTests.swift`

### Implementation for User Story 3

- [X] T033 [US3] Add stable metadata fields for future categories (description/order/visibility rules) in `Minute/Sources/Views/Settings/SettingsCategoryCatalog.swift`
- [X] T034 [US3] Persist and restore last valid category selection in `Minute/Sources/Views/Settings/MainSettingsView.swift`
- [X] T035 [US3] Add hidden-category fallback routing logic in `Minute/Sources/Views/Settings/MainSettingsView.swift`
- [X] T036 [US3] Add developer-facing category extension guidance comments in `Minute/Sources/Views/Settings/SettingsCategoryCatalog.swift`

**Checkpoint**: All user stories are independently functional and testable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, cleanup, and documentation.

- [X] T037 [P] Remove or simplify unused settings wrapper views in `Minute/Sources/Views/Settings/SettingsView.swift`
- [X] T038 [P] Remove or simplify unused settings wrapper views in `Minute/Sources/Views/Settings/SettingsContentView.swift`
- [X] T039 Record manual acceptance evidence for single-window + continuity checks in `specs/012-settings-improvements/quickstart.md`
- [X] T040 Run and document app test validation command results in `specs/012-settings-improvements/quickstart.md`
- [X] T041 Run and document MinuteCore test validation command results in `specs/012-settings-improvements/quickstart.md`
- [X] T042 Confirm output-contract regression checks remain green and document result in `specs/012-settings-improvements/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies.
- **Phase 2 (Foundational)**: Depends on Phase 1; blocks all user stories.
- **Phase 3 (US1)**: Depends on Phase 2.
- **Phase 4 (US2)**: Depends on Phase 3 for integrated single-window workspace behavior.
- **Phase 5 (US3)**: Depends on Phase 4 category model reorganization.
- **Phase 6 (Polish)**: Depends on completion of desired user stories.

### User Story Dependencies

- **US1 (P1)**: First deliverable; establishes full-window single-window settings behavior and continuity guardrails.
- **US2 (P2)**: Builds on US1 workspace to improve category discoverability and setting reachability.
- **US3 (P3)**: Builds on US2 metadata-driven categories to make growth and fallback behavior robust.

### Within Each User Story

- Tests MUST be written first and fail before implementation.
- Routing/state primitives before UI composition updates.
- Category metadata before sidebar/detail bindings.
- Story completion before moving to next priority.

### Parallel Opportunities

- Setup: T002 and T003 can run in parallel after T001.
- Foundational: T006 can run in parallel with T004/T005/T007 once scaffolds exist.
- US1: T009 and T010 can run in parallel; T017 and T018 can run in parallel after T014.
- US2: T019 and T020 can run in parallel; T024-T028 can run in parallel after T022.
- US3: T030 and T031 can run in parallel; T034 and T036 can run in parallel after T033.
- Polish: T037 and T038 can run in parallel; T040 and T041 can run in parallel.

---

## Parallel Example: User Story 1

```bash
# Parallel test creation
Task T009: MinuteTests/SettingsWorkspaceRoutingTests.swift
Task T010: MinuteTests/SettingsWorkspaceContinuityTests.swift

# Parallel post-routing implementation
Task T017: Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
Task T018: Minute/Sources/Views/Pipeline/PipelineContentView.swift
```

## Parallel Example: User Story 2

```bash
# Parallel test creation
Task T019: MinuteTests/SettingsCategoryCatalogTests.swift
Task T020: MinuteTests/SettingsSectionReachabilityTests.swift

# Parallel category composition updates
Task T024: Minute/Sources/Views/Settings/GeneralSettingsSection.swift
Task T025: Minute/Sources/Views/Settings/ModelsSettingsSection.swift
Task T026: Minute/Sources/Views/Settings/PermissionsSettingsSection.swift
Task T027: Minute/Sources/Views/Settings/VaultConfigurationView.swift
Task T028: Minute/Sources/Views/Settings/KnownSpeakersSettingsSection.swift
```

## Parallel Example: User Story 3

```bash
# Parallel regression tests
Task T030: MinuteTests/SettingsCategorySelectionFallbackTests.swift
Task T031: MinuteTests/SettingsWorkspaceIdempotencyTests.swift

# Parallel growth hardening tasks
Task T034: Minute/Sources/Views/Settings/MainSettingsView.swift
Task T036: Minute/Sources/Views/Settings/SettingsCategoryCatalog.swift
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 and Phase 2.
2. Complete Phase 3 (US1).
3. Validate independent test for US1 (single-window settings + uninterrupted recording/work).
4. Demo/deploy MVP.

### Incremental Delivery

1. Deliver US1 (workspace conversion + continuity).
2. Deliver US2 (discoverability and organization).
3. Deliver US3 (scalability/fallback hardening).
4. Finish polish and full regression validation.

### Parallel Team Strategy

1. Team completes Setup + Foundational together.
2. Then split by workstreams where safe:
   - Developer A: routing and continuity tasks.
   - Developer B: category taxonomy and UI grouping tasks.
   - Developer C: test and regression coverage tasks.

---

## Notes

- [P] tasks indicate file-level parallelism without unmet dependencies.
- [US#] labels map each task to a specific user story for traceability.
- Keep commits small and aligned to task IDs.
- Re-run validation commands from `specs/012-settings-improvements/quickstart.md` after each story checkpoint.
