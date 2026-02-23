# Parity Checkpoints: Architecture Simplification Refactor

Track before/after parity for critical workflows during each refactor slice.

## Critical Flows

- [x] Recording start/stop/cancel behavior parity verified
- [x] Pipeline processing stage progression parity verified
- [x] Background processing retry/cancel behavior parity verified
- [x] Meeting notes list/select/load parity verified
- [x] Speaker naming and transcript rewrite parity verified
- [x] Onboarding model setup flow parity verified
- [x] Settings model validation/download flow parity verified
- [x] Recovery/discard recording behavior parity verified
- [x] Screen context capture selection and lifecycle parity verified
- [x] Output contract remains unchanged (exact 3 files) verified

## Regression Matrix

| Checkpoint ID | Workflow Area | Scenario | Before Result | After Result | Status | Evidence |
|---------------|---------------|----------|---------------|--------------|--------|----------|
| CP-001 | WA-PIPELINE | Recording start/stop/cancel | pass | pass | passed | `MinuteTests/MeetingPipelineViewModelCancelSessionTests.swift` + `xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO` |
| CP-002 | WA-PIPELINE | Processing stage progression | pass | pass | passed | `MinuteCore/Tests/MinuteCoreTests/MeetingProcessingOrchestratorTests.swift` + `xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO` |
| CP-003 | WA-NOTES | Notes load and overlay behavior | pass | pass | passed | `MinuteTests/MinuteTests.swift` (`MeetingNotesBrowserViewModelSpeakerDraftIsolationTests`) |
| CP-004 | WA-NOTES | Speaker naming/transcript rewrite | pass | pass | passed | `MinuteCore/Tests/MinuteCoreTests/MeetingSpeakerNamingServiceTests.swift` + `MinuteCore/Tests/MinuteCoreTests/TranscriptSpeakerHeadingRewriterTests.swift` |
| CP-005 | WA-MODELS | Onboarding + settings model lifecycle | pass | pass | passed | `MinuteTests/MinuteTests.swift` (`ModelSetupLifecycleParityCoverageTests`) + `MinuteTests/ModelsSettingsViewModelVocabularyGatingTests.swift` |
| CP-006 | WA-VAULT | Path normalization and contract paths | pass | pass | passed | `MinuteCore/Tests/MinuteCoreTests/VaultPathNormalizerTests.swift` + `MinuteCore/Tests/MinuteCoreTests/VaultMeetingNotesBrowserTests.swift` |
| CP-007 | WA-SCREENCAP | Capture wrappers and window lifecycle | pass | pass | passed | `MinuteCore/Tests/MinuteCoreTests/ScreenCaptureKitAdapterTests.swift` + `MinuteCore/Tests/MinuteCoreTests/ScreenContextCaptureServiceWindowLifecycleTests.swift` |
