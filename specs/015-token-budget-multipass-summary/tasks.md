# Tasks: Token Budget and Multi-Pass Summarization

**Input**: Design documents from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are REQUIRED for this feature (MinuteCore behavior changes + pipeline state changes).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare feature scaffolding and test organization

- [X] T001 Create feature task tracking notes in /Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/tasks.md
- [X] T002 [P] Add test fixture transcript inputs for long multi-pass scenarios in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/Fixtures/
- [X] T003 [P] Add feature-focused test file skeletons in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core abstractions and persistence foundations required by all stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Define run-state domain types (`TokenBudgetEstimate`, `SummarizationPassPlan`, `SummaryStateSnapshot`, `PassExecutionRecord`, `SummarizationRunState`) in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/
- [X] T005 Define protocol for checkpoint persistence/recovery in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift
- [X] T006 Implement app-owned checkpoint store service (outside vault) in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/
- [X] T007 [P] Add unit tests for checkpoint store read/write/recovery behavior in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/
- [X] T008 Add pipeline-level concurrency guard abstraction for single active run per meeting in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/
- [X] T009 [P] Add unit tests for single-active-run guard behavior in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Reliable Long Meeting Processing (Priority: P1) 🎯 MVP

**Goal**: Process long transcripts via deterministic multi-pass summarization and progressively update the same summary document safely.

**Independent Test**: Run a transcript exceeding single-pass capacity; verify multi-pass completion, per-pass valid updates, no duplicate chunk coverage, and final valid summary.

### Tests for User Story 1 (REQUIRED) ⚠️

- [X] T010 [P] [US1] Add red test for deterministic chunk planning and non-overlapping token ranges in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/
- [X] T011 [P] [US1] Add red test for per-pass valid summary checkpoint updates in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/
- [X] T012 [P] [US1] Add red test for no fixed pass cap (continues until all chunks consumed) in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/
- [X] T013 [P] [US1] Add red test for duplicate prevention across chunk boundaries in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/

### Implementation for User Story 1

- [X] T014 [US1] Implement deterministic transcript token chunk planner in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/
- [X] T015 [US1] Integrate multi-pass run loop into /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [X] T016 [US1] Add pass-level structured output validation + checkpoint commit logic in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [X] T017 [US1] Implement incremental summary merge and deduplication rules in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/
- [X] T018 [US1] Ensure atomic update of the same summary document after each successful pass in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [X] T019 [US1] Enforce single active run per meeting and clear rejection message path in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [X] T020 [US1] Update run/pass status domain mapping and error handling in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/MinuteError.swift

**Checkpoint**: User Story 1 is independently functional and testable (MVP)

---

## Phase 4: User Story 2 - Predictable Capacity Before Run (Priority: P2)

**Goal**: Provide preflight token budget and pass estimate before summarization starts.

**Independent Test**: For multiple transcript sizes, verify preflight returns non-zero budget and stable pass estimate visible before execution begins.

### Tests for User Story 2 (REQUIRED) ⚠️

- [X] T021 [P] [US2] Add red test for preflight budget calculation with reserves in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/
- [X] T022 [P] [US2] Add red test for estimated pass-count computation drift handling in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/
- [X] T023 [P] [US2] Add red test for preflight contract fields alignment (`/summarization/preflight`) in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/

### Implementation for User Story 2

- [X] T024 [US2] Implement budget preflight calculator service in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/
- [X] T025 [US2] Wire preflight invocation before run start in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [X] T026 [US2] Integrate preflight values into summarization service configuration in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLlama/Services/LlamaLibrarySummarizationService.swift
- [X] T027 [US2] Surface preflight budget and estimated pass count in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T028 [US2] Update pipeline status presentation for preflight and estimated passes in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/PipelineStatusPresenter.swift
- [X] T047 [US2] Add hardware-aware summarization context window selection in onboarding/settings and align preflight + runtime context usage in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/ and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/

**Checkpoint**: User Story 2 is independently functional and testable

---

## Phase 5: User Story 3 - Resilient Recovery During Multi-Pass Runs (Priority: P3)

**Goal**: Preserve last valid checkpoint on failure and resume from checkpoint across app restarts.

**Independent Test**: Force a middle-pass failure, restart app context, resume run, and verify processing continues from next uncompleted pass.

### Tests for User Story 3 (REQUIRED) ⚠️

- [X] T029 [P] [US3] Add red test for failure rollback to last valid checkpoint in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/
- [X] T030 [P] [US3] Add red test for resume-after-restart using existing app-owned recovery path in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/
- [X] T031 [P] [US3] Add red test for cancel preserving latest valid checkpoint in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/
- [X] T032 [P] [US3] Add red test for run status transitions (`running -> paused_for_retry -> running`) in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/

### Implementation for User Story 3

- [X] T033 [US3] Persist pass checkpoints through existing app-owned recovery store in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [X] T034 [US3] Implement resume orchestration from `last_valid_snapshot.completed_pass_index + 1` in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [X] T035 [US3] Implement failure containment and paused-for-retry state transitions in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [X] T036 [US3] Add cancel path checkpoint retention behavior in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift
- [X] T037 [US3] Surface resume/recovery status and restart-safe messaging in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift

**Checkpoint**: User Story 3 is independently functional and testable

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Hardening, documentation, and full validation

- [X] T038 [P] Align contract documentation with final behavior in /Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/contracts/openapi.yaml
- [X] T039 [P] Update quickstart validation steps with final commands and scenarios in /Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/quickstart.md
- [X] T040 Run full MinuteCore test suite for regression validation via `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'`
- [X] T041 Run app build validation via `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build`
- [X] T042 [P] Update release-facing docs for summarization behavior changes in /Users/roblibob/Projects/FLX/Minute/Minute/docs/
- [X] T043 [US1] Add runtime-aware summarization service hooks so the coordinator can refine pass plans without breaking non-llama implementations in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/
- [X] T044 [US1] Reuse the loaded llama model across runtime planning, classification, and pass execution in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLlama/Services/LlamaLibrarySummarizationService.swift
- [X] T045 [P] [US2] Add coordinator regression coverage for runtime-refined pass plans in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/
- [X] T046 [P] Update spec/plan/quickstart documentation for tokenizer-based runtime refinement in /Users/roblibob/Projects/FLX/Minute/Minute/specs/015-token-budget-multipass-summary/
- [X] T048 [US1] Replace model-authored full-summary rewrites with chunk-local pass deltas and deterministic in-app merge state in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/ and /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteLlama/

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies.
- **Phase 2 (Foundational)**: Depends on Phase 1; blocks all user stories.
- **Phase 3 (US1)**: Depends on Phase 2.
- **Phase 4 (US2)**: Depends on Phase 2; can proceed after US1 MVP validation.
- **Phase 5 (US3)**: Depends on Phase 2 and uses US1 pass/checkpoint foundations.
- **Phase 6 (Polish)**: Depends on completion of selected user stories.

### User Story Dependencies

- **US1 (P1)**: No dependency on other stories after Foundational.
- **US2 (P2)**: No strict dependency on US1, but benefits from shared run-state structures.
- **US3 (P3)**: Depends on US1 multi-pass/checkpoint flow being in place.

### Recommended Story Order

1. US1 (MVP)
2. US2
3. US3

---

## Parallel Execution Examples

### Parallel Example: User Story 1

```bash
Task: "T010 [US1] deterministic chunk planning test"
Task: "T011 [US1] checkpoint update test"
Task: "T012 [US1] no pass cap test"
Task: "T013 [US1] dedupe test"
```

### Parallel Example: User Story 2

```bash
Task: "T021 [US2] preflight reserve test"
Task: "T022 [US2] estimate drift test"
Task: "T023 [US2] preflight contract-field test"
```

### Parallel Example: User Story 3

```bash
Task: "T029 [US3] rollback checkpoint test"
Task: "T030 [US3] resume-after-restart test"
Task: "T031 [US3] cancel checkpoint retention test"
Task: "T032 [US3] status transition test"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 and Phase 2.
2. Deliver Phase 3 (US1) end-to-end.
3. Validate independent US1 test criteria.
4. Demo/deploy MVP behavior.

### Incremental Delivery

1. Add US2 preflight visibility.
2. Add US3 restart-safe recovery and resume.
3. Finish with polish and full regression validation.

### Parallel Team Strategy

1. Team completes Setup + Foundational together.
2. After Foundational:
   - Developer A: US1 implementation and tests.
   - Developer B: US2 preflight/test work.
   - Developer C: US3 recovery/test work (after US1 checkpoint baseline lands).

---

## Notes

- [P] tasks indicate file-independent work that can run concurrently.
- Each user story phase is independently testable per spec criteria.
- Keep output contract unchanged (exactly three vault files).
- Preserve local-only processing and deterministic output behavior.
