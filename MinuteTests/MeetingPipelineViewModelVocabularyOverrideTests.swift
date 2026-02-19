import Foundation
import Testing
@testable import Minute
@preconcurrency @testable import MinuteCore

struct MeetingPipelineViewModelVocabularyOverrideTests {
    @Test
    func customTermsPersistForActiveSession_andResetAfterCancel() async throws {
        let suite = "MeetingPipelineViewModelVocabularyOverrideLifecycle.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        backendStore.setSelectedBackendID(TranscriptionBackend.fluidAudio.rawValue)

        let stageStore = StagePreferencesStore(defaults: defaults)
        stageStore.clear()

        let vaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: nil))
        let coordinator = await MainActor.run {
            makeCoordinator(vaultAccess: vaultAccess)
        }

        var model: MeetingPipelineViewModel? = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: MockAudioService(),
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: vaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: stageStore,
                transcriptionBackendStore: backendStore,
                vocabularySettingsStore: MockVocabularyBoostingSettingsStore(
                    settings: GlobalVocabularyBoostingSettings(
                        enabled: true,
                        strength: .balanced,
                        terms: ["Acme"]
                    )
                ),
                sessionVocabularyResolver: SessionVocabularyResolver(),
                modelValidationProvider: {
                    ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
                }
            )
        }

        await MainActor.run {
            model?.setSessionVocabularyMode(.custom)
            model?.setSessionCustomVocabularyInput("Taylor, Roadmap")
            model?.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                if case .recording = model.state {
                    return true
                }
                return false
            }
        }

        await MainActor.run {
            #expect(model?.sessionVocabularyMode == .custom)
            #expect(model?.sessionCustomVocabularyInput == "Taylor, Roadmap")
            model?.send(.cancelRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                if case .idle = model.state {
                    return model.sessionVocabularyMode == .default
                        && model.sessionCustomVocabularyInput.isEmpty
                }
                return false
            }
        }

        await MainActor.run {
            model = nil
        }
    }

    @Test
    func missingModels_setsNonBlockingVocabularyWarningOnSessionStart() async throws {
        let suite = "MeetingPipelineViewModelVocabularyOverrideWarning.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        backendStore.setSelectedBackendID(TranscriptionBackend.fluidAudio.rawValue)

        let stageStore = StagePreferencesStore(defaults: defaults)
        stageStore.clear()

        let vaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: nil))
        let coordinator = await MainActor.run {
            makeCoordinator(vaultAccess: vaultAccess)
        }

        var model: MeetingPipelineViewModel? = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: MockAudioService(),
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: vaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: stageStore,
                transcriptionBackendStore: backendStore,
                vocabularySettingsStore: MockVocabularyBoostingSettingsStore(
                    settings: GlobalVocabularyBoostingSettings(
                        enabled: true,
                        strength: .balanced,
                        terms: ["Acme"]
                    )
                ),
                sessionVocabularyResolver: SessionVocabularyResolver(),
                modelValidationProvider: {
                    ModelValidationResult(missingModelIDs: ["fluidaudio/asr-v3-ctc-vocab"], invalidModelIDs: [])
                }
            )
        }

        await MainActor.run {
            model?.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 1_000_000_000) {
            await MainActor.run {
                guard let model else { return false }
                if case .recording = model.state {
                    return (model.sessionVocabularyWarningMessage?.contains("without boosting") == true)
                }
                return false
            }
        }

        await MainActor.run {
            model?.send(.cancelRecording)
            model = nil
        }
    }

    @MainActor
    private func makeCoordinator(vaultAccess: VaultAccess) -> MeetingPipelineCoordinator {
        let summarizationServiceProvider: @Sendable () -> any SummarizationServicing = { MockSummarizationService() }
        return MeetingPipelineCoordinator(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationServiceProvider: summarizationServiceProvider,
            modelManager: MockModelManager(),
            vaultAccess: vaultAccess,
            vaultWriter: DefaultVaultWriter()
        )
    }
}
