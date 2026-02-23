# Ownership Map

## Purpose

This document defines canonical ownership boundaries for core workflow areas.
Each source path should have one primary workflow owner.

## Workflow Areas

| Area ID | Area Name | Scope | Primary Entry Points | Owner Modules | Status |
|---------|-----------|-------|----------------------|---------------|--------|
| WA-PIPELINE | Pipeline Session & Processing | Recording lifecycle, processing orchestration, status progression | `Minute/Sources/ViewModels/MeetingPipelineViewModel.swift`, `Minute/Sources/ViewModels/PipelineStatusPresenter.swift`, `Minute/Sources/ViewModels/PipelineDefaultsObserver.swift`, `MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift` | `Minute/Sources/ViewModels/`, `MinuteCore/Sources/MinuteCore/Pipeline/` | stabilized |
| WA-NOTES | Meeting Notes Browsing & Editing | Notes list/load actions, speaker naming workflows, transcript viewing transforms | `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift`, `Minute/Sources/Views/MeetingNotes/MeetingNotesOverlayState.swift`, `Minute/Sources/Views/MeetingNotes/MarkdownViewerOverlay.swift`, `MinuteCore/Sources/MinuteCore/Rendering/MeetingNoteParsing.swift` | `Minute/Sources/Views/MeetingNotes/`, `MinuteCore/Sources/MinuteCore/Rendering/` | stabilized |
| WA-MODELS | Model Setup & Validation | Model selection, validation, download lifecycle across onboarding/settings | `Minute/Sources/Views/Onboarding/OnboardingViewModel.swift`, `Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift`, `Minute/Sources/ViewModels/ModelSetupLifecycleController.swift`, `MinuteCore/Sources/MinuteCore/Services/DefaultModelManager.swift` | `Minute/Sources/Views/Onboarding/`, `Minute/Sources/Views/Settings/`, `Minute/Sources/ViewModels/`, `MinuteCore/Sources/MinuteCore/Services/` | stabilized |
| WA-VAULT | Vault Pathing & File Contract Access | Relative-path normalization and vault path resolution for notes/audio/transcripts | `MinuteCore/Sources/MinuteCore/Services/VaultMeetingNotesBrowser.swift`, `MinuteCore/Sources/MinuteCore/Vault/VaultPathNormalizer.swift` | `MinuteCore/Sources/MinuteCore/Vault/`, `MinuteCore/Sources/MinuteCore/Services/` | stabilized |
| WA-SCREENCAP | Screen Capture Integration | Window discovery, screenshot/capture wrappers, screen context capture flows | `Minute/Sources/Views/ScreenContextRecordingPickerView.swift`, `MinuteCore/Sources/MinuteCore/Services/ScreenContextCaptureService.swift`, `MinuteCore/Sources/MinuteCore/Services/SystemAudioCapture.swift`, `MinuteCore/Sources/MinuteCore/Services/ScreenCaptureKitAdapter.swift` | `Minute/Sources/Views/`, `MinuteCore/Sources/MinuteCore/Services/` | stabilized |

## Baseline Ownership Detail

| Area ID | Stateful Owner | Pure-Transform Owner | Integration Boundary | Baseline Parity Checkpoints |
|---------|----------------|----------------------|----------------------|-----------------------------|
| WA-PIPELINE | `Minute/Sources/ViewModels/MeetingPipelineViewModel.swift` + `Minute/Sources/ViewModels/PipelineDefaultsObserver.swift` | `Minute/Sources/ViewModels/PipelineStatusPresenter.swift` + `MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift` | Audio capture + vault writes | `CP-001`, `CP-002` |
| WA-NOTES | `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift` + `Minute/Sources/Views/MeetingNotes/MeetingNotesOverlayState.swift` | `MinuteCore/Sources/MinuteCore/Rendering/MeetingNoteParsing.swift` | Vault note/transcript reads | `CP-003`, `CP-004` |
| WA-MODELS | `Minute/Sources/ViewModels/ModelSetupLifecycleController.swift` | `MinuteCore/Sources/MinuteCore/Services/DefaultModelManager.swift` | Local model validation/download | `CP-005` |
| WA-VAULT | `MinuteCore/Sources/MinuteCore/Services/VaultMeetingNotesBrowser.swift` | `MinuteCore/Sources/MinuteCore/Vault/VaultPathNormalizer.swift` | Path normalization + relative contract paths | `CP-006` |
| WA-SCREENCAP | `MinuteCore/Sources/MinuteCore/Services/ScreenCaptureKitAdapter.swift` | `MinuteCore/Sources/MinuteCore/Services/ScreenContextCaptureService.swift` | ScreenCaptureKit wrappers + lifecycle events | `CP-007` |

## Consolidation Records

| Unit ID | Behavior | Canonical Owner | Replaced Sources | Evidence |
|---------|----------|-----------------|------------------|----------|
| CB-013-001 | Model setup lifecycle state and downloads | `Minute/Sources/ViewModels/ModelSetupLifecycleController.swift` | `Minute/Sources/Views/Onboarding/OnboardingViewModel.swift`, `Minute/Sources/Views/Settings/ModelsSettingsViewModel.swift` | `CP-005` |
| CB-013-002 | Vault relative path normalization | `MinuteCore/Sources/MinuteCore/Vault/VaultPathNormalizer.swift` | `MinuteCore/Sources/MinuteCore/Services/VaultMeetingNotesBrowser.swift`, `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift` | `CP-006` |
| CB-013-003 | ScreenCaptureKit async wrappers/configuration | `MinuteCore/Sources/MinuteCore/Services/ScreenCaptureKitAdapter.swift` | `Minute/Sources/Views/ScreenContextRecordingPickerView.swift`, `MinuteCore/Sources/MinuteCore/Services/ScreenContextCaptureService.swift`, `MinuteCore/Sources/MinuteCore/Services/SystemAudioCapture.swift` | `CP-007` |
| CB-013-004 | Meeting note speaker/transcript parsing transforms | `MinuteCore/Sources/MinuteCore/Rendering/MeetingNoteParsing.swift` | `Minute/Sources/Views/MeetingNotes/MeetingNotesBrowserViewModel.swift`, `Minute/Sources/Views/MeetingNotes/MarkdownViewerOverlay.swift` | `CP-003`, `CP-004` |

## Ownership Rules

- A source path must have one primary workflow owner.
- Shared behavior must have one canonical implementation owner.
- Temporary migration adapters must be documented and removed before refactor completion.

## Review Protocol

- Update this document in every refactor slice that moves ownership.
- Add migration-note entries for moved, deleted, renamed, or consolidated surfaces.
- Confirm parity checkpoints are passed before marking a workflow area as stabilized.
