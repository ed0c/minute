# Tasks: Custom Meeting Type Prompts

**Input**: Design documents from `/specs/014-custom-meeting-prompts/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/openapi.yaml, quickstart.md

**Tests**: Tests are REQUIRED for this feature (new feature + MinuteCore behavior changes + contract-sensitive pipeline flow).

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no unresolved dependencies)
- **[Story]**: User story label (`[US1]`, `[US2]`, `[US3]`) for story-phase tasks only
- Each task includes concrete file path(s)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add feature scaffolding in app/settings and core modules used by all stories.

- [X] T001 Add the new `meetingTypes` settings category case and metadata in `Minute/Sources/Views/Settings/SettingsCategoryCatalog.swift`
- [X] T002 Add a new settings route branch for Meeting Types in `Minute/Sources/Views/Settings/MainSettingsView.swift`
- [X] T003 [P] Create Meeting Types settings view scaffold in `Minute/Sources/Views/Settings/MeetingTypesSettingsSection.swift`
- [X] T004 [P] Create Meeting Types settings view model scaffold in `Minute/Sources/ViewModels/MeetingTypesSettingsViewModel.swift`
- [X] T005 [P] Create prompt library domain scaffold in `MinuteCore/Sources/MinuteCore/Domain/MeetingTypeLibrary.swift`
- [X] T006 [P] Create prompt library service scaffold in `MinuteCore/Sources/MinuteCore/Services/MeetingTypeLibraryStore.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement shared prompt-library model, persistence, and resolver foundations that block all user stories.

**⚠️ CRITICAL**: No user story work should begin until this phase is complete.

- [X] T007 Add failing validation tests for prompt component and meeting type definitions in `MinuteCore/Tests/MinuteCoreTests/MeetingTypeLibraryValidationTests.swift`
- [X] T008 [P] Add failing persistence tests for prompt library load/save behavior in `MinuteCore/Tests/MinuteCoreTests/MeetingTypeLibraryStoreTests.swift`
- [X] T009 [P] Add failing migration tests for legacy stage meeting type preferences in `MinuteCore/Tests/MinuteCoreTests/StagePreferencesStoreMigrationTests.swift`
- [X] T010 [P] Add failing deterministic prompt assembly tests in `MinuteCore/Tests/MinuteCoreTests/ResolvedPromptBundleResolverTests.swift`
- [X] T011 Implement prompt-library entities and validation rules in `MinuteCore/Sources/MinuteCore/Domain/MeetingTypeLibrary.swift`
- [X] T012 Implement local persistence for library + built-in overrides in `MinuteCore/Sources/MinuteCore/Services/MeetingTypeLibraryStore.swift`
- [X] T013 Implement resolved prompt bundle assembly service in `MinuteCore/Sources/MinuteCore/Services/ResolvedPromptBundleResolver.swift`
- [X] T014 Add prompt-library protocols and mock surfaces in `MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift` and `MinuteCore/Sources/MinuteCore/Services/MockServices.swift`
- [X] T015 Migrate stage selection persistence from enum-only values to stable type IDs in `MinuteCore/Sources/MinuteCore/Domain/StagePreferences.swift` and `MinuteCore/Sources/MinuteCore/Services/StagePreferencesStore.swift`
- [X] T016 Add shared fixture builders for prompt-library tests in `MinuteCore/Tests/MinuteCoreTests/TestSupport/PromptLibraryFixture.swift`

**Checkpoint**: Foundation ready. User stories can now be implemented and tested independently.

---

## Phase 3: User Story 1 - Create Custom Meeting Types (Priority: P1) 🎯 MVP

**Goal**: Let users create custom meeting types with custom prompts and use them in processing.

**Independent Test**: Create a custom meeting type in Settings, select it in stage UI, process a meeting, and verify inference uses that custom prompt.

### Tests for User Story 1

- [X] T017 [P] [US1] Add create/list/update custom meeting type behavior tests in `MinuteCore/Tests/MinuteCoreTests/MeetingTypeLibraryCustomTypeTests.swift`
- [X] T018 [P] [US1] Add pipeline test ensuring manual custom selection drives summarization prompt resolution in `MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorCustomMeetingTypeTests.swift`
- [X] T019 [P] [US1] Add app-level settings routing test for Meeting Types section visibility in `MinuteTests/SettingsSectionReachabilityTests.swift`
- [X] T020 [P] [US1] Add app-level create-custom-type settings workflow test in `MinuteTests/MeetingTypesSettingsViewModelTests.swift`

### Implementation for User Story 1

- [X] T021 [US1] Implement custom meeting type create/list/update operations in `MinuteCore/Sources/MinuteCore/Services/MeetingTypeLibraryStore.swift`
- [X] T022 [US1] Implement Meeting Types settings view model create/save validation flow in `Minute/Sources/ViewModels/MeetingTypesSettingsViewModel.swift`
- [X] T023 [US1] Implement Meeting Types settings section list/editor UI in `Minute/Sources/Views/Settings/MeetingTypesSettingsSection.swift`
- [X] T024 [US1] Integrate library-backed meeting type options into stage state in `Minute/Sources/ViewModels/MeetingPipelineViewModel.swift`
- [X] T025 [US1] Replace static enum-only meeting type menu with dynamic list rendering in `Minute/Sources/Views/Pipeline/Stage/SessionViews.swift`
- [X] T026 [US1] Add prompt bundle usage path in summarization execution in `MinuteCore/Sources/MinuteLlama/Services/LlamaLibrarySummarizationService.swift` and `MinuteCore/Sources/MinuteCore/Summarization/Prompts/PromptFactory.swift`
- [X] T027 [US1] Pass selection IDs and resolved type context through pipeline context and coordinator in `MinuteCore/Sources/MinuteCore/Pipeline/PipelineTypes.swift` and `MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`

**Checkpoint**: US1 is complete and independently testable as the MVP increment.

---

## Phase 4: User Story 2 - Edit Default Prompts (Priority: P2)

**Goal**: Let users edit built-in meeting type prompts and restore defaults safely.

**Independent Test**: Edit a built-in prompt, process a meeting and verify override is used, then restore default and verify baseline prompt is used again.

### Tests for User Story 2

- [X] T028 [P] [US2] Add built-in override save/restore persistence tests in `MinuteCore/Tests/MinuteCoreTests/BuiltInPromptOverrideStoreTests.swift`
- [X] T029 [P] [US2] Add resolved prompt source-kind tests for built-in default vs override in `MinuteCore/Tests/MinuteCoreTests/ResolvedPromptBundleResolverTests.swift`
- [X] T030 [P] [US2] Add app-level built-in restore-default interaction test in `MinuteTests/MeetingTypesSettingsViewModelTests.swift`

### Implementation for User Story 2

- [X] T031 [US2] Implement built-in override persistence and restore logic in `MinuteCore/Sources/MinuteCore/Services/MeetingTypeLibraryStore.swift`
- [X] T032 [US2] Implement built-in override/restore actions in `Minute/Sources/ViewModels/MeetingTypesSettingsViewModel.swift`
- [X] T033 [US2] Implement built-in prompt editor state and restore UI action in `Minute/Sources/Views/Settings/MeetingTypesSettingsSection.swift`
- [X] T034 [US2] Ensure resolved prompt bundles prioritize built-in overrides while preserving built-in type identity in `MinuteCore/Sources/MinuteCore/Services/ResolvedPromptBundleResolver.swift`
- [X] T035 [US2] Surface built-in status badges (default vs overridden) in settings list and stage display in `Minute/Sources/Views/Settings/MeetingTypesSettingsSection.swift` and `Minute/Sources/Views/Pipeline/Stage/SessionViews.swift`

**Checkpoint**: US2 is complete and independently testable.

---

## Phase 5: User Story 3 - Maintain Prompt Library Safely (Priority: P3)

**Goal**: Provide safe rename/delete flows, stale-selection guardrails, and custom-type autodetect integration.

**Independent Test**: Rename and delete custom types with validation/confirmation, verify built-ins cannot be deleted, and verify autodetect can resolve eligible custom types with fallback to `general`.

### Tests for User Story 3

- [X] T036 [P] [US3] Add rename/delete validation and uniqueness tests in `MinuteCore/Tests/MinuteCoreTests/MeetingTypeLibraryCustomTypeTests.swift`
- [X] T037 [P] [US3] Add classifier prompt/parse tests for autodetect-eligible custom labels in `MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierCustomTypesTests.swift`
- [X] T038 [P] [US3] Add pipeline test for stale deleted selection blocking processing in `MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorCustomMeetingTypeTests.swift`
- [X] T039 [P] [US3] Add app-level delete-confirmation and stale-selection warning tests in `MinuteTests/MeetingPipelineViewModelMeetingTypeSafetyTests.swift`

### Implementation for User Story 3

- [X] T040 [US3] Implement rename/delete guardrails and stale-reference detection in `MinuteCore/Sources/MinuteCore/Services/MeetingTypeLibraryStore.swift` and `MinuteCore/Sources/MinuteCore/Services/ResolvedPromptBundleResolver.swift`
- [X] T041 [US3] Extend classifier label generation/parsing for custom eligible types in `MinuteCore/Sources/MinuteCore/Summarization/Services/MeetingTypeClassifier.swift`
- [X] T042 [US3] Integrate autodetect custom-type resolution and fallback handling in `MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`
- [X] T043 [US3] Add processing-time invalid-selection blocking and user-facing error handling in `Minute/Sources/ViewModels/MeetingPipelineViewModel.swift`
- [X] T044 [US3] Implement rename/delete confirmation and classifier profile editing controls in `Minute/Sources/Views/Settings/MeetingTypesSettingsSection.swift`

**Checkpoint**: US3 is complete and independently testable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final contract, regression, and documentation alignment across all stories.

- [X] T045 [P] Update Meeting Types settings coverage assertions in `MinuteTests/SettingsCategoryCatalogTests.swift`, `MinuteTests/SettingsCategoryGrowthTests.swift`, and `MinuteTests/SettingsWorkspaceContractTests.swift`
- [X] T046 [P] Add output-contract regression coverage for custom/built-in prompt paths in `MinuteCore/Tests/MinuteCoreTests/OutputContractCoverageTests.swift`
- [X] T047 Update feature documentation for Meeting Types settings placement and usage in `docs/overview.md` and `specs/014-custom-meeting-prompts/quickstart.md`
- [X] T048 Run full validation matrix and record execution evidence in `specs/014-custom-meeting-prompts/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies; starts immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1; blocks all story work.
- **Phase 3 (US1)**: Depends on Phase 2 completion.
- **Phase 4 (US2)**: Depends on Phase 2 completion; can run in parallel with late US1 tasks if file ownership does not conflict.
- **Phase 5 (US3)**: Depends on Phase 2 completion and is safest after US1 core integration lands.
- **Phase 6 (Polish)**: Depends on all targeted user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Independent after foundational completion.
- **US2 (P2)**: Independent after foundational completion; relies on shared library foundations but not on US1 business behavior.
- **US3 (P3)**: Independent after foundational completion, but practically depends on US1 custom-type integration for full safety-flow verification.

### Dependency Graph (Story Order)

- Recommended delivery order: `US1 -> US2 -> US3`
- MVP scope: `US1`

---

## Parallel Execution Examples

### User Story 1

```bash
# Parallel US1 tests
T017 MinuteCore/Tests/MinuteCoreTests/MeetingTypeLibraryCustomTypeTests.swift
T018 MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorCustomMeetingTypeTests.swift
T019 MinuteTests/SettingsSectionReachabilityTests.swift
T020 MinuteTests/MeetingTypesSettingsViewModelTests.swift
```

### User Story 2

```bash
# Parallel US2 tests
T028 MinuteCore/Tests/MinuteCoreTests/BuiltInPromptOverrideStoreTests.swift
T029 MinuteCore/Tests/MinuteCoreTests/ResolvedPromptBundleResolverTests.swift
T030 MinuteTests/MeetingTypesSettingsViewModelTests.swift
```

### User Story 3

```bash
# Parallel US3 tests
T036 MinuteCore/Tests/MinuteCoreTests/MeetingTypeLibraryCustomTypeTests.swift
T037 MinuteCore/Tests/MinuteCoreTests/Summarization/MeetingTypeClassifierCustomTypesTests.swift
T038 MinuteCore/Tests/MinuteCoreTests/MeetingPipelineCoordinatorCustomMeetingTypeTests.swift
T039 MinuteTests/MeetingPipelineViewModelMeetingTypeSafetyTests.swift
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 and Phase 2.
2. Complete Phase 3 (US1).
3. Validate US1 independent test criteria.
4. Demo/deploy MVP before expanding scope.

### Incremental Delivery

1. Deliver US1: custom type creation and processing usage.
2. Deliver US2: built-in prompt editing and restore defaults.
3. Deliver US3: safe management guardrails + custom autodetect.
4. Finish with Phase 6 polish/regression/documentation.

### Parallel Team Strategy

1. Team completes Setup + Foundational together.
2. Split by story after foundation:
   - Engineer A: US1
   - Engineer B: US2
   - Engineer C: US3 test scaffolding and classifier extensions
3. Merge by priority with story-level checkpoints.

---

## Notes

- `[P]` tasks are parallelizable by dependency and file boundaries.
- All story-phase tasks include `[US#]` labels for traceability.
- Each story includes explicit independent test criteria.
- Keep test-first workflow: write failing tests before implementation tasks.
