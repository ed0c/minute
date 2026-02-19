---

description: "Task list for Vocabulary Boosting Controls"

---

# Tasks: Vocabulary Boosting Controls

**Input**: Design documents from `/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/`
**Prerequisites**: `/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/plan.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/spec.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/research.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/data-model.md`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/contracts/openapi.yaml`, `/Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/quickstart.md`

**Tests**: REQUIRED (constitution + plan + quickstart require test-first coverage for MinuteCore policy logic and app-level backend-aware UI behavior).

**Organization**: Tasks are grouped by user story so each story remains independently implementable and testable.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Complete Step 0 dependency upgrade and baseline validation setup.

- [X] T001 Upgrade FluidAudio dependency version constraint in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Package.swift
- [X] T002 Resolve Swift package graph after upgrade and commit lock changes in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Package.resolved
- [X] T003 Record dependency-upgrade verification commands/results in /Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/quickstart.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add shared vocabulary domain, persistence, normalization, and policy contracts required by all stories.

**⚠️ CRITICAL**: No user story implementation starts before this phase is complete.

- [X] T004 Add vocabulary domain types (strength, mode, readiness, term entry) in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Domain/VocabularyBoosting.swift
- [X] T005 Add vocabulary-related defaults keys and defaults in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Configuration/AppConfiguration.swift
- [X] T006 Implement persistent global vocabulary settings store in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/VocabularyBoostingSettingsStore.swift
- [X] T007 Implement session override resolver (Off/Default/Custom, additive merge, empty-custom fallback) in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/SessionVocabularyResolver.swift
- [X] T008 Extend shared protocol surface for vocabulary settings/readiness access in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift
- [X] T009 Update mock service implementations for new vocabulary protocol abstractions in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/MockServices.swift
- [X] T010 Add unit tests for global vocabulary settings store load/save/clear behavior in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/VocabularyBoostingSettingsStoreTests.swift
- [X] T011 [P] Add unit tests for session resolver effective-mode and merge rules in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/SessionVocabularyResolverTests.swift
- [X] T012 [P] Extend defaults/config coverage for vocabulary keys in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/AppConfigurationTests.swift

**Checkpoint**: Shared vocabulary contracts and deterministic policy behavior are in place; user stories can proceed.

---

## Phase 3: User Story 1 - Configure global vocabulary boosting (Priority: P1) 🎯 MVP

**Goal**: Allow users to configure reusable global vocabulary boosting in Settings when using FluidAudio.

**Independent Test**: With FluidAudio selected, user can enable vocabulary boosting, enter comma/newline terms, choose Gentle/Balanced/Aggressive, save, and see settings persist on reopen.

### Tests for User Story 1 (REQUIRED)

- [X] T013 [P] [US1] Add app-level tests for global toggle, term parsing input, and strength persistence in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/ModelsSettingsViewModelVocabularyBoostingTests.swift
- [X] T014 [P] [US1] Add core normalization tests for whitespace, blank lines, and case-insensitive dedupe in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/VocabularyTermNormalizationTests.swift

### Implementation for User Story 1

- [X] T015 [US1] Extend settings view model state/actions for global vocabulary enable, terms, and strength in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift
- [X] T016 [US1] Add Vocabulary Boosting block (toggle, multi-term editor, strength selector) in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsSection.swift
- [X] T017 [US1] Add reusable vocabulary settings subview for term/strength controls in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/VocabularyBoostingSection.swift
- [X] T018 [US1] Map global settings load behavior to `/v1/settings/vocabulary-boosting` contract semantics in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift
- [X] T019 [US1] Map global settings save/update behavior to `/v1/settings/vocabulary-boosting` contract semantics in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift

**Checkpoint**: US1 is independently functional and shippable as MVP.

---

## Phase 4: User Story 2 - Override vocabulary per recording session (Priority: P2)

**Goal**: Provide per-session Off/Default/Custom vocabulary controls with session-lifetime persistence and additive custom terms.

**Independent Test**: In three separate sessions set Off, Default, and Custom; verify Off disables boosting, Default uses global settings, Custom uses Global + Session terms, and empty custom falls back to Default.

### Tests for User Story 2 (REQUIRED)

- [X] T020 [P] [US2] Add app-level tests for session vocabulary mode selection and custom-popover flow in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/MeetingPipelineViewModelVocabularyOverrideTests.swift
- [X] T021 [P] [US2] Add core tests for effective term-set composition and empty-custom fallback in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/SessionVocabularyEffectiveTermsTests.swift

### Implementation for User Story 2

- [X] T022 [US2] Extend recording-session state with vocabulary override mode and custom term lifetime handling in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T023 [US2] Add Vocabulary Off/Default/Custom row and inline hint text to session card UI in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Pipeline/Stage/SessionViews.swift
- [X] T024 [US2] Add compact custom-terms popover UI for meeting-specific vocabulary entries in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Pipeline/Stage/SessionVocabularyPopover.swift
- [X] T025 [US2] Ensure custom session terms persist only for active session lifetime and reset on completion/cancel in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T026 [US2] Extend FluidAudio transcription configuration to accept effective vocabulary terms/strength in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/FluidAudioTranscriptionService.swift
- [X] T027 [US2] Apply effective vocabulary terms at transcription execution time for FluidAudio sessions in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/FluidAudioTranscriptionService.swift
- [X] T028 [US2] Map `/v1/sessions/{sessionId}/vocabulary` get/set semantics in session view model behavior in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift

**Checkpoint**: US2 is independently functional and does not require US3 readiness work to verify core override behavior.

---

## Phase 5: User Story 3 - Understand availability and readiness (Priority: P3)

**Goal**: Gate vocabulary controls by backend capability and surface missing required vocab-model readiness with non-blocking session-start fallback.

**Independent Test**: Switch backend between Whisper and FluidAudio to verify control gating; with missing vocab models, see inline status in Settings and start recording with boosting disabled plus warning/status.

### Tests for User Story 3 (REQUIRED)

- [X] T029 [P] [US3] Add app-level tests for backend-aware visibility/disable behavior in settings and session UI in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteTests/ModelsSettingsViewModelVocabularyGatingTests.swift
- [X] T030 [P] [US3] Extend model manager tests for missing vocabulary model readiness behavior in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/DefaultModelManagerTests.swift

### Implementation for User Story 3

- [X] T031 [US3] Extend FluidAudio model validation/download flows for required vocabulary model readiness in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/FluidAudioASRModelManager.swift
- [X] T032 [US3] Expose vocabulary readiness state/messages through model validation aggregation in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Sources/MinuteCore/Services/DefaultModelManager.swift
- [X] T033 [US3] Render inline vocabulary readiness status/action row in AI settings when backend is FluidAudio in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Settings/ModelsSettingsSection.swift
- [X] T034 [US3] Hide or disable session vocabulary controls when backend is Whisper in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/Views/Pipeline/Stage/SessionViews.swift
- [X] T035 [US3] Enforce non-blocking session-start fallback (start allowed, boosting disabled, warning surfaced) in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift
- [X] T036 [US3] Map readiness warning field behavior for `/v1/sessions/{sessionId}/vocabulary` responses in /Users/roblibob/Projects/FLX/Minute/Minute/Minute/Sources/ViewModels/MeetingPipelineViewModel.swift

**Checkpoint**: US3 is independently functional and communicates capability/readiness state clearly.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final regression hardening, docs, and end-to-end validation across all stories.

- [X] T037 [P] Update manual QA checklist with vocabulary boosting scenarios in /Users/roblibob/Projects/FLX/Minute/Minute/docs/tasks/10-packaging-sandbox-signing-and-qa.md
- [X] T038 [P] Add regression assertions that output contract file behavior remains unchanged in /Users/roblibob/Projects/FLX/Minute/Minute/MinuteCore/Tests/MinuteCoreTests/OutputContractCoverageTests.swift
- [X] T039 Run quickstart validation scenarios and capture actual outcomes in /Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/quickstart.md
- [X] T040 Run build/test commands and append results in /Users/roblibob/Projects/FLX/Minute/Minute/specs/011-vocabulary-boosting/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: no dependencies.
- **Phase 2 (Foundational)**: depends on Phase 1; blocks all user stories.
- **Phase 3 (US1)**: depends on Phase 2 only.
- **Phase 4 (US2)**: depends on Phase 2; can start after US1 checkpoint if team prefers strict incrementality.
- **Phase 5 (US3)**: depends on Phase 2; can run in parallel with US2 if staffing allows.
- **Phase 6 (Polish)**: depends on completed target user stories.

### User Story Dependency Graph

- **US1 (P1)** -> MVP baseline (global vocabulary configuration)
- **US2 (P2)** -> extends behavior with per-session override and effective term composition
- **US3 (P3)** -> capability/readiness gating and non-blocking missing-model fallback

### Story Completion Order

- Recommended: **US1 -> US2 -> US3**
- Parallel-capable after Phase 2: **US2** and **US3** (with careful merge planning in shared files)

---

## Parallel Execution Examples

### User Story 1

- Run in parallel: `T013` and `T014` (app tests vs core tests in different targets/files).

### User Story 2

- Run in parallel: `T020` and `T021` (app and core tests in separate files).

### User Story 3

- Run in parallel: `T029` and `T030` (app gating tests and core model-manager tests).

---

## Implementation Strategy

### MVP First (US1 only)

1. Complete Phase 1 and Phase 2.
2. Complete Phase 3 (US1).
3. Validate US1 independent test criteria and ship/demo MVP.

### Incremental Delivery

1. Deliver US1 (global settings).
2. Deliver US2 (session overrides) and validate independently.
3. Deliver US3 (backend gating/readiness fallback) and validate independently.
4. Complete Phase 6 polish and full regression run.

### Completeness Validation

- Every user story has explicit tests and implementation tasks.
- Contract coverage is mapped per story:
  - US1: `/v1/settings/vocabulary-boosting` (`GET`, `PUT`)
  - US2: `/v1/sessions/{sessionId}/vocabulary` (`GET`, `PUT`) for mode/term behavior
  - US3: readiness warning behavior on `/v1/sessions/{sessionId}/vocabulary` and settings readiness state
- Each story has independent test criteria and can be validated without completing later stories.

---

## Notes

- `[P]` tasks are parallelizable when they touch different files and have no unmet dependencies.
- `[USx]` labels map directly to user stories in `spec.md` for traceability.
- Keep TDD order per story: write tests first, verify failure, then implement.
- Avoid changing output-file contract behavior (exactly three vault files per meeting).
