import Foundation
import MinuteCore
import Testing
@testable import Minute

struct MeetingPipelineViewModelSilenceAutoStopTests {
    @Test
    func autoStop_withoutUserAction_stopsRecordingAfterWarningCountdown() async throws {
        let audioService = AutoSilenceAudioService()

        let suiteName = "MeetingPipelineViewModelSilenceAutoStopTests"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let stagePreferencesStore = StagePreferencesStore(defaults: defaults)
        stagePreferencesStore.clear()

        let coordinatorVaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: nil))
        let viewModelVaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: nil))
        let summarizationServiceProvider: @Sendable () -> any SummarizationServicing = { MockSummarizationService() }

        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationServiceProvider: summarizationServiceProvider,
            modelManager: MockModelManager(),
            vaultAccess: coordinatorVaultAccess,
            vaultWriter: DefaultVaultWriter()
        )

        let alertNotifier = await MainActor.run { MockRecordingAlertNotifier() }
        let shortPolicy = SilenceDetectionPolicy(
            silenceDurationSeconds: 0.15,
            warningCountdownSeconds: 0.15,
            rmsSilenceThreshold: 0.8,
            transientToleranceSeconds: 0
        )

        var model: MeetingPipelineViewModel? = await MainActor.run {
            MeetingPipelineViewModel(
                audioService: audioService,
                mediaImportService: MockMediaImportService(),
                recoveryService: MockRecordingRecoveryService(),
                pipelineCoordinator: coordinator,
                screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
                screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
                screenContextSettingsStore: ScreenContextSettingsStore(),
                vaultAccess: viewModelVaultAccess,
                recordingPermissions: .alwaysGranted(),
                stagePreferencesStore: stagePreferencesStore,
                silenceDetectionPolicy: shortPolicy,
                recordingAlertNotifier: alertNotifier
            )
        }

        await MainActor.run {
            model?.send(.startRecording)
        }

        try await eventually(timeoutNanoseconds: 2_000_000_000) {
            let stopCalls = await audioService.stopRecordingCalls
            return stopCalls > 0
        }

        let sawAutoStopEvent = await MainActor.run {
            guard let model else { return false }
            return model.recordingSessionEvents.contains { $0.eventType == .autoStopExecuted }
        }
        #expect(sawAutoStopEvent)

        await MainActor.run {
            model = nil
        }
    }
}
