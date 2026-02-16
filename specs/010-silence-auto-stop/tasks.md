---

description: "Task list for Silence Auto Stop"

---

# Tasks: Silence Auto Stop

**Input**: Design documents from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/`
**Prerequisites**: `/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/plan.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/spec.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/research.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/data-model.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/contracts/openapi.yaml`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/quickstart.md`

**Tests**: REQUIRED (constitution + plan + quickstart mandate test-first coverage for silence transitions, notification actions, and window-closed handling).

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add test support and reusable fixtures used across all stories.

- [X] T001 Add deterministic timing helper for silence countdown tests in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/TestSupport/SilenceAutoStopTestClock.swift
- [X] T002 [P] Add notification-center spy for local alert assertions in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/TestSupport/NotificationCenterSpy.swift
- [X] T003 [P] Add app-level notification action test helper in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/TestSupport/NotificationActionTestSupport.swift
- [X] T004 [P] Add screen-context window lifecycle fixtures in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/Helpers/ScreenContextWindowLifecycleFixtures.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build shared domain/protocol/notification foundations required by every story.

**⚠️ CRITICAL**: No user story implementation starts before this phase is complete.

- [X] T005 Extend notification constants/actions for silence warning, keep-recording, and screen-window-closed alerts in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/MicActivityNotifications.swift
- [X] T006 Update app notification category registration and delegate routing for new recording-alert actions in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/App/MinuteApp.swift
- [X] T007 [P] Add recording alert and session event domain models in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/RecordingAlerts.swift
- [X] T008 [P] Add silence detection policy/state domain models in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/SilenceDetection.swift
- [X] T009 Extend service interfaces for silence monitoring and recording-alert notifications in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift
- [X] T010 Add mock implementations for new silence/alert service interfaces in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/MockServices.swift
- [X] T011 Add domain validation tests for alert/event/silence models in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/RecordingAlertModelsTests.swift

**Checkpoint**: Shared contracts and notification plumbing are in place; user stories can proceed independently.

---

## Phase 3: User Story 1 - Auto-stop after sustained silence (Priority: P1) 🎯 MVP

**Goal**: Detect 2 minutes of RMS silence, warn for 30 seconds, and auto-stop recording if no user intervention occurs.

**Independent Test**: Start recording, speak briefly, remain silent for at least 2 minutes, do not interact, and verify warning + automatic stop at countdown completion.

### Tests for User Story 1 (REQUIRED)

- [X] T012 [P] [US1] Add unit tests for 120-second silence trigger and 30-second auto-stop deadline in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/SilenceAutoStopControllerTests.swift
- [X] T013 [P] [US1] Add app-level integration test for auto-stop without user action in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingPipelineViewModelSilenceAutoStopTests.swift

### Implementation for User Story 1

- [X] T014 [US1] Implement silence monitoring and countdown state machine in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/SilenceAutoStopController.swift
- [X] T015 [US1] Integrate live audio-level stream with silence controller lifecycle in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T016 [US1] Trigger stop-warning alerts and session event entries at the 2-minute threshold in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T017 [US1] Execute automatic recording stop when countdown expires with continued silence in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T018 [US1] Render in-app silence warning countdown fallback UI during recording in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Pipeline/PipelineContentView.swift
- [X] T019 [US1] Expose silence status snapshot used by `/recording/silence/status` contract mapping in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T020 [US1] Record `silence_warning_issued` and `auto_stop_executed` events for stop rationale tracking in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift

**Checkpoint**: US1 is independently functional and meets MVP behavior.

---

## Phase 4: User Story 2 - Continue recording from warning (Priority: P2)

**Goal**: Let users keep recording from the warning action and cancel pending auto-stop on resumed speech.

**Independent Test**: Trigger a silence warning, select keep-recording action, and confirm recording continues without unintended stop from that warning cycle.

### Tests for User Story 2 (REQUIRED)

- [X] T021 [P] [US2] Add unit tests for keep-recording and speech-resume cancellation transitions in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/SilenceAutoStopControllerKeepRecordingTests.swift
- [X] T022 [P] [US2] Add app-level test for keep-recording action routing and canceled auto-stop in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingPipelineViewModelKeepRecordingTests.swift

### Implementation for User Story 2

- [X] T023 [US2] Implement actionable recording-alert notification coordinator with keep-recording support in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/RecordingAlertNotificationCoordinator.swift
- [X] T024 [US2] Wire keep-recording notification action dispatch into app delegate handling in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/App/MinuteApp.swift
- [X] T025 [US2] Handle keep-recording actions to cancel pending auto-stop and resume monitoring in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T026 [US2] Cancel warning countdown when speech resumes and log `warning_canceled_by_speech` events in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T027 [US2] Clear warning UI immediately after keep-recording or speech-resume cancellation in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Pipeline/PipelineContentView.swift
- [X] T028 [US2] Expose keep-recording resolution outcomes for `/recording/silence/warning/keep-recording` and `/recording/events` contract mapping in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift

**Checkpoint**: US2 is independently functional and prevents unwanted stop when meeting continues.

---

## Phase 5: User Story 3 - Screen context closure warning (Priority: P3)

**Goal**: Notify users when an actively shared window closes, including coexistence with silence warnings.

**Independent Test**: Record with screen context enabled, close selected window, and verify user-visible closure alert while keep-recording action remains accessible if silence warning is also active.

### Tests for User Story 3 (REQUIRED)

- [X] T029 [P] [US3] Add unit tests for window-closed detection versus transient capture failure in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/ScreenContextCaptureServiceWindowLifecycleTests.swift
- [X] T030 [P] [US3] Add app-level tests for window-closed alert delivery and coexistence with silence warnings in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingPipelineViewModelScreenContextAlertsTests.swift

### Implementation for User Story 3

- [X] T031 [US3] Emit explicit shared-window-closed lifecycle events from screen capture loop in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ScreenContextCaptureService.swift
- [X] T032 [US3] Route window-closed lifecycle events into user-visible recording alerts in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T033 [US3] Send local notification for shared-window-closed alerts with permission fallback support in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/RecordingAlertNotificationCoordinator.swift
- [X] T034 [US3] Render shared-window-closed in-app banner without hiding keep-recording action in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Pipeline/PipelineContentView.swift
- [X] T035 [US3] Add alert acknowledgment handling for `/recording/alerts/{alertId}/acknowledge` contract mapping in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T036 [US3] Log `screen_window_closed_notified` session events for verification in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift

**Checkpoint**: US3 is independently functional and reliably surfaces shared-window-closed state.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, docs, and regression hardening across all stories.

- [X] T037 [P] Update release and QA notes for silence auto-stop behavior in /Users/roblibob/Projects/FLX/Minute/Minute/docs/tasks/10-packaging-sandbox-signing-and-qa.md
- [X] T038 [P] Add cross-cutting cancellation and stop-reason regression tests in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/MeetingProcessingOrchestratorCancelTests.swift
- [X] T039 Run quickstart validation scenarios and update execution notes in /Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/quickstart.md
- [X] T040 Run full app and MinuteCore test commands and append results in /Users/roblibob/Projects/FLX/Minute/Minute/specs/010-silence-auto-stop/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 (Setup): no dependencies.
- Phase 2 (Foundational): depends on Phase 1 and blocks all user stories.
- Phase 3 (US1): depends on Phase 2 only.
- Phase 4 (US2): depends on Phase 2; integrates with US1 warning flow but remains independently testable.
- Phase 5 (US3): depends on Phase 2; can run in parallel with US2 once shared notification plumbing exists.
- Phase 6 (Polish): depends on completed target stories.

### User Story Dependency Graph

- US1 (P1) -> MVP baseline
- US2 (P2) -> extends US1 warning flow with keep-recording and resumed-speech cancellation
- US3 (P3) -> independent of US2 business logic, but shares recording alert infrastructure from Phase 2

### Story Completion Order

- Recommended: US1 -> US2 -> US3
- Parallel-capable after Phase 2 with sufficient staffing: US2 and US3

---

## Parallel Execution Examples

### User Story 1

- Run in parallel: `T012` and `T013` (different test targets/files).

### User Story 2

- Run in parallel: `T021` and `T022` (different test targets/files).

### User Story 3

- Run in parallel: `T029` and `T030` (core test + app test in separate files).

---

## Implementation Strategy

### MVP First (US1 only)

1. Complete Phase 1 and Phase 2.
2. Deliver Phase 3 (US1) and validate independent test criteria.
3. Demo/review MVP before extending behavior.

### Incremental Delivery

1. Add US2 keep-recording behavior and validate independently.
2. Add US3 shared-window-closed alerts and validate independently.
3. Finish with Phase 6 polish and full regression pass.

### Completeness Validation

- Every user story has explicit tests, implementation tasks, and independent test criteria.
- Contract-mapped behaviors are covered:
  - US1: `/recording/silence/status`
  - US2: `/recording/silence/warning/keep-recording`, `/recording/events`
  - US3: `/recording/alerts/{alertId}/acknowledge`
