import Foundation
import MinuteCore
import Testing
@testable import Minute

struct MeetingPipelineViewModelKeepRecordingTests {
    @Test
    func keepRecordingAction_cancelsPendingAutoStop() async throws {
        let audioService = AutoSilenceAudioService()

        let suiteName = "MeetingPipelineViewModelKeepRecordingTests"
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
            warningCountdownSeconds: 0.4,
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
            await MainActor.run {
                model?.activeSilenceAlert != nil
            }
        }

        await MainActor.run {
            model?.keepRecordingFromWarning()
        }

        try await Task.sleep(nanoseconds: 700_000_000)

        let stopCalls = await audioService.stopRecordingCalls
        #expect(stopCalls == 0)

        let sawKeepRecordingEvent = await MainActor.run {
            guard let model else { return false }
            return model.recordingSessionEvents.contains { $0.eventType == .keepRecordingSelected }
        }
        #expect(sawKeepRecordingEvent)

        await MainActor.run {
            model?.send(.cancelRecording)
            model = nil
        }
    }
}
