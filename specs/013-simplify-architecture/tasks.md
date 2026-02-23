# Tasks: Architecture Simplification Refactor

**Input**: Design documents from `/specs/013-simplify-architecture/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/openapi.yaml, quickstart.md

**Tests**: Tests are REQUIRED for this refactor because the spec and constitution require behavior parity for critical workflows and updates to affected test suites.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no unresolved dependencies)
- **[Story]**: User story label (`[US1]`, `[US2]`, `[US3]`) for story-phase tasks only
- Each task includes concrete file path(s)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish refactor tracking artifacts and execution scaffolding used by all stories.

- [X] T001 Create ownership map documentation scaffold in `docs/architecture/ownership-map.md`
- [X] T002 Create migration note scaffold in `docs/architecture/refactor-migration.md`
- [X] T003 [P] Create parity checkpoint tracker in `specs/013-simplify-architecture/checklists/parity-checkpoints.md`
- [X] T004 [P] Add refactor fixture support file in `MinuteTests/TestSupport/RefactorFixtureBuilders.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build shared foundations that block all user stories until complete.

**⚠️ CRITICAL**: Do not start user-story implementation until this phase is complete.

- [X] T005 Add baseline critical-flow parity smoke tests in `MinuteTests/ArchitectureParitySmokeTests.swift`
- [X] T006 [P] Add MinuteCore parity test support helpers in `MinuteCore/Tests/MinuteCoreTests/TestSupport/RefactorParityTestSupport.swift`
- [X] T007 [P] Add shared pipeline/coordinator fixture helpers in `MinuteCore/Tests/MinuteCoreTests/TestSupport/PipelineCoordinatorFixture.swift`
- [X] T008 Populate baseline workflow ownership entries in `docs/architecture/ownership-map.md`
- [X] T009 Define migration-note entry schema and update protocol in `docs/architecture/refactor-migration.md`

**Checkpoint**: Foundation ready. User stories can proceed.

---

## Phase 3: User Story 1 - Simplify Core Navigation (Priority: P1) 🎯 MVP

**Goal**: Make ownership and navigation of core workflow behavior obvious by decomposing mixed-responsibility surfaces.

**Independent Test**: A contributor can locate and explain recording, processing, and notes ownership in one pass, and debug a workflow without traversing unrelated modules.

### Tests for User Story 1

- [X] T010 [P] [US1] Add status mapping unit tests in `MinuteTests/PipelineStatusPresenterTests.swift`
- [X] T011 [P] [US1] Add defaults-observation behavior tests in `MinuteTests/PipelineDefaultsObserverTests.swift`
- [X] T012 [P] [US1] Add notes-overlay state ownership tests in `MinuteTests/MeetingNotesOverlayStateTests.swift`

### Implementation for User Story 1

- [X] T013 [US1] Extract status-drawer mapping logic from `Minute/Sources/Views/Pipeline/PipelineContentView.swift` into `Minute/Sources/ViewModels/PipelineStatusPresenter.swift`
- [X] T014 [US1] Extract defaults-change snapshot/refresh coordination from `Minute/Sources/ViewModels/MeetingPipelineViewModel.swift` into `Minute/Sources/ViewModels/PipelineDefaultsObserver.swift`
- [X] T015 [US1] Extract note overlay state orchestration from `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift` into `Minute/Sources/Views/MeetingNotes/MeetingNotesOverlayState.swift`
- [X] T016 [US1] Update pipeline and notes ownership entries for new module boundaries in `docs/architecture/ownership-map.md`
- [X] T017 [US1] Record moved/renamed module entries in `docs/architecture/refactor-migration.md`

**Checkpoint**: US1 is independently functional and navigable.

---

## Phase 4: User Story 2 - Remove Accidental Complexity (Priority: P2)

**Goal**: Consolidate duplicated behavior into canonical owners and remove pass-through layers.

**Independent Test**: A targeted behavior change in one workflow area requires edits in only one canonical implementation location.

### Tests for User Story 2

- [X] T018 [P] [US2] Add shared model-lifecycle parity tests in `MinuteTests/MinuteTests.swift`
- [X] T019 [P] [US2] Add shared path-normalization tests in `MinuteCore/Tests/MinuteCoreTests/VaultPathNormalizerTests.swift`
- [X] T020 [P] [US2] Add ScreenCaptureKit adapter behavior tests in `MinuteCore/Tests/MinuteCoreTests/ScreenCaptureKitAdapterTests.swift`

### Implementation for User Story 2

- [X] T021 [US2] Consolidate onboarding/settings model setup lifecycle into `Minute/Sources/ViewModels/ModelSetupLifecycleController.swift` and refactor `Minute/Sources/Views/Onboarding/OnboardingViewModel.swift` and `Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift`
- [X] T022 [US2] Consolidate vault relative-path normalization into `MinuteCore/Sources/MinuteCore/Vault/VaultPathNormalizer.swift` and refactor `MinuteCore/Sources/MinuteCore/Services/VaultMeetingNotesBrowser.swift` and `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift`
- [X] T023 [US2] Consolidate ScreenCaptureKit wrappers into `MinuteCore/Sources/MinuteCore/Services/ScreenCaptureKitAdapter.swift` and refactor `MinuteCore/Sources/MinuteCore/Services/ScreenContextCaptureService.swift`, `MinuteCore/Sources/MinuteCore/Services/SystemAudioCapture.swift`, and `Minute/Sources/Views/ScreenContextRecordingPickerView.swift`
- [X] T024 [US2] Move shared meeting-note parsing/transform logic into `MinuteCore/Sources/MinuteCore/Rendering/MeetingNoteParsing.swift` and refactor `Minute/Sources/Views/MeetingNotes/MarkdownViewerOverlay.swift` and `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift`
- [X] T025 [US2] Update shared behavior consolidation records in `docs/architecture/ownership-map.md` and `docs/architecture/refactor-migration.md`

**Checkpoint**: US2 consolidation is complete and independently verifiable.

---

## Phase 5: User Story 3 - Eliminate Dead Code Paths (Priority: P3)

**Goal**: Remove unreachable, obsolete, and redundant paths while preserving behavior parity.

**Independent Test**: Dead-code audit findings are removed or explicitly rejected with parity evidence and no regression in critical flows.

### Tests for User Story 3

- [X] T026 [P] [US3] Add dead-code parity guard tests in `MinuteTests/MinuteTests.swift`
- [X] T027 [P] [US3] Refactor repeated setup to shared fixtures in `MinuteTests/MeetingPipelineViewModelCancelSessionTests.swift` and validate via `MinuteTests/MeetingPipelineViewModelKeepRecordingTests.swift`
- [X] T028 [P] [US3] Add dead-path regression checks for meeting notes flow in `MinuteTests/MeetingNotesBrowserViewModelSpeakerDraftIsolationTests.swift`

### Implementation for User Story 3

- [X] T029 [US3] Remove superseded branches/helpers in `Minute/Sources/ViewModels/MeetingPipelineViewModel.swift` after extracted owners are wired
- [X] T030 [US3] Remove superseded branches/helpers in `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift` and `Minute/Sources/Views/MeetingNotes/MarkdownViewerOverlay.swift`
- [X] T031 [US3] Remove temporary migration scaffolding and obsolete compatibility shims in `MinuteCore/Sources/MinuteCore/Services/DefaultModelManager.swift`, `MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift`, and `MinuteCore/Sources/MinuteCore/Services/MockServices.swift`
- [X] T032 [US3] Update dead-code findings and closure evidence in `docs/architecture/refactor-migration.md` and `specs/013-simplify-architecture/checklists/parity-checkpoints.md`

**Checkpoint**: US3 dead-code outcomes are complete and independently testable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final cross-story hardening, documentation alignment, and validation.

- [X] T033 [P] Align architecture overview with final ownership boundaries in `docs/overview.md` and `docs/architecture/ownership-map.md`
- [X] T034 Validate quickstart execution notes and finalize evidence in `specs/013-simplify-architecture/quickstart.md`
- [X] T035 [P] Reconcile abstract contract and completed workflow states in `specs/013-simplify-architecture/contracts/openapi.yaml`
- [X] T036 Run full regression test matrix and record final pass summary in `specs/013-simplify-architecture/checklists/parity-checkpoints.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies; start immediately.
- **Phase 2 (Foundational)**: Depends on Phase 1; blocks all user stories.
- **Phase 3 (US1)**: Depends on Phase 2 completion.
- **Phase 4 (US2)**: Depends on Phase 2 completion; can overlap US1 only where file ownership does not conflict.
- **Phase 5 (US3)**: Depends on completion of US1 and US2 refactor slices it cleans up.
- **Phase 6 (Polish)**: Depends on all user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Independent after foundational phase.
- **US2 (P2)**: Independent after foundational phase but may sequence after US1 to reduce merge conflicts in shared hotspots.
- **US3 (P3)**: Depends on refactor outputs from US1 and US2 to safely remove superseded paths.

### Dependency Graph (Story Order)

- `US1 -> US2 -> US3` (recommended delivery order)
- `US1` is MVP scope.
- `US2` and `US3` extend and finalize simplification.

---

## Parallel Execution Examples

### User Story 1

```bash
# Parallel US1 test creation
T010 MinuteTests/PipelineStatusPresenterTests.swift
T011 MinuteTests/PipelineDefaultsObserverTests.swift
T012 MinuteTests/MeetingNotesOverlayStateTests.swift
```

### User Story 2

```bash
# Parallel US2 test creation
T018 MinuteTests/ModelSetupLifecycleParityTests.swift
T019 MinuteCore/Tests/MinuteCoreTests/VaultPathNormalizerTests.swift
T020 MinuteCore/Tests/MinuteCoreTests/ScreenCaptureKitAdapterTests.swift
```

### User Story 3

```bash
# Parallel US3 validation tests
T026 MinuteTests/ArchitectureDeadCodeParityTests.swift
T027 MinuteTests/MeetingPipelineViewModelCancelSessionTests.swift
T028 MinuteTests/MeetingNotesBrowserViewModelSpeakerDraftIsolationTests.swift
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 1 and Phase 2.
2. Complete Phase 3 (US1).
3. Validate US1 independent test criteria and parity checks.
4. Stop for review/demo before expanding scope.

### Incremental Delivery

1. Deliver US1 navigation simplification and ownership clarity.
2. Deliver US2 consolidation of shared behavior and duplicated logic.
3. Deliver US3 dead-code elimination and cleanup.
4. Finish with cross-cutting polish and full regression validation.

### Parallel Team Strategy

1. Team completes Setup + Foundational phases together.
2. Split by story after foundation:
   - Engineer A: US1
   - Engineer B: US2 (non-conflicting slices)
   - Engineer C: US3 prep tests and parity instrumentation
3. Merge in priority order with parity checkpoints enforced.

---

## Notes

- `[P]` tasks are parallelizable by file and dependency boundaries.
- Story labels map each story-phase task directly to user value.
- Every task includes actionable file paths for immediate execution.
- Keep abstractions shallow: avoid adding wrapper layers without explicit ownership value.
