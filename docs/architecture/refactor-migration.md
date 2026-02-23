# Refactor Migration Note

## Purpose

Tracks contributor-facing migration entries for moved, renamed, deleted, and consolidated surfaces introduced by architecture simplification.

## Entry Schema

Each entry should include:

- `note_id`: Stable identifier (for example `MN-001`).
- `change_type`: `moved` | `renamed` | `deleted` | `consolidated`.
- `old_location`: Previous path/symbol location (if applicable).
- `new_location`: New path/symbol location (if applicable).
- `impact_summary`: Plain-language impact for contributors.
- `effective_version`: Version or milestone tag.
- `parity_checkpoint_ids`: Related parity checkpoints that validate behavior parity.
- `reviewed_by`: Contributor approving parity evidence.
- `follow_up_required`: `yes` | `no` (and issue link when `yes`).
- `sunset_condition`: Condition required before any temporary shim removal.

## Entries

| Note ID | Change Type | Old Location | New Location | Impact Summary | Effective Version | Parity Checkpoints |
|---------|-------------|--------------|--------------|----------------|-------------------|--------------------|
| MN-013-001 | consolidated | `Minute/Sources/Views/Pipeline/PipelineContentView.swift` status drawer mapping section | `Minute/Sources/ViewModels/PipelineStatusPresenter.swift` | Status drawer mapping logic is centralized and testable; UI file now focuses on view wiring and action dispatch. | 013-us1 | `CP-001`, `CP-002` |
| MN-013-002 | consolidated | `Minute/Sources/ViewModels/MeetingPipelineViewModel.swift` defaults snapshot/change detection section | `Minute/Sources/ViewModels/PipelineDefaultsObserver.swift` | Defaults observation now uses an explicit snapshot/change policy object, reducing hidden branching in the pipeline view model. | 013-us1 | `CP-001`, `CP-005` |
| MN-013-003 | consolidated | `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift` overlay selection/tab/dismiss fields | `Minute/Sources/Views/MeetingNotes/MeetingNotesOverlayState.swift` | Notes overlay presentation state transitions are now isolated from I/O and speaker naming behavior. | 013-us1 | `CP-003`, `CP-004` |
| MN-013-004 | consolidated | duplicated model setup lifecycle in onboarding/settings view models | `Minute/Sources/ViewModels/ModelSetupLifecycleController.swift` | Shared model validation/download lifecycle now has one owner used by both onboarding and settings surfaces. | 013-us2 | `CP-005` |
| MN-013-005 | consolidated | ad-hoc vault-relative path helpers in notes/browser surfaces | `MinuteCore/Sources/MinuteCore/Vault/VaultPathNormalizer.swift` | Vault-relative path normalization now routes through a single canonical utility. | 013-us2 | `CP-006` |
| MN-013-006 | consolidated | duplicated ScreenCaptureKit continuation and screenshot configuration helpers | `MinuteCore/Sources/MinuteCore/Services/ScreenCaptureKitAdapter.swift` | ScreenCaptureKit integration behavior now has one adapter used across picker and capture services. | 013-us2 | `CP-007` |
| MN-013-007 | consolidated | speaker/transcript parsing helpers in notes view-model and overlay | `MinuteCore/Sources/MinuteCore/Rendering/MeetingNoteParsing.swift` | Meeting note parsing/rewriting logic now lives in one shared rendering utility. | 013-us2 | `CP-003`, `CP-004` |
| MN-013-008 | deleted | `Minute/Sources/ViewModels/MeetingPipelineViewModel.swift` private `FailingTranscriptionService` shim | removed | Obsolete fallback helper removed after resilience path ownership stabilized in `ResilientWhisperTranscriptionService`. | 013-us3 | `CP-001`, `CP-002` |
| MN-013-009 | deleted | `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift` parser pass-through wrappers | removed | Redundant wrapper layer removed; callers use `MeetingNoteParsing` directly. | 013-us3 | `CP-003`, `CP-004` |
| MN-013-010 | deleted | stale migration-task comments in `MinuteCore/Sources/MinuteCore/Services/MockServices.swift` and `MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift` | removed | Temporary migration scaffolding comments removed to keep current ownership/documentation accurate. | 013-us3 | `CP-005`, `CP-006`, `CP-007` |

## Dead Code Findings

| Finding ID | Path | Finding | Resolution | Evidence |
|------------|------|---------|------------|----------|
| DCF-013-001 | `Minute/Sources/ViewModels/MeetingPipelineViewModel.swift` | Unused fallback shim type | Removed | `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO` |
| DCF-013-002 | `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift` | Redundant parser wrapper methods | Removed and replaced with direct `MeetingNoteParsing` calls | `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO` |
| DCF-013-003 | `MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift` | Local relative-path normalization shim | Consolidated into `VaultPathNormalizer` usage | `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO` |

## Update Protocol

1. Add an entry in the same pull request that moves, renames, deletes, or consolidates code.
2. Populate `parity_checkpoint_ids` with concrete IDs from `specs/013-simplify-architecture/checklists/parity-checkpoints.md`.
3. Keep entries append-only during active migration; do not rewrite prior change rows.
4. Mark `follow_up_required` as `yes` for any temporary adapter and include tracking issue text in `impact_summary`.
5. Set `sunset_condition` for compatibility shims (for example: "remove after CP-003 and CP-004 pass").
6. Remove temporary scaffolding only after matching `sunset_condition` is satisfied and parity checkpoints are marked passed.
