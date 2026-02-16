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

private actor AutoSilenceAudioService: AudioServicing, AudioLevelMetering, AudioCaptureControlling {
    private var levelHandler: (@Sendable (Float) -> Void)?
    private var loopTask: Task<Void, Never>?
    private(set) var stopRecordingCalls = 0

    func startRecording() async throws {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.emitSilenceLevel()
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
        }
    }

    func cancelRecording() async {
        loopTask?.cancel()
        loopTask = nil
    }

    func stopRecording() async throws -> AudioCaptureResult {
        stopRecordingCalls += 1
        loopTask?.cancel()
        loopTask = nil
        throw MinuteError.audioExportFailed
    }

    func convertToContractWav(inputURL: URL, outputURL: URL) async throws {
        _ = inputURL
        _ = outputURL
    }

    func setLevelHandler(_ handler: (@Sendable (Float) -> Void)?) async {
        levelHandler = handler
    }

    func setMicrophoneEnabled(_ enabled: Bool) async {
        _ = enabled
    }

    func setSystemAudioEnabled(_ enabled: Bool) async {
        _ = enabled
    }

    private func emitSilenceLevel() {
        levelHandler?(0)
    }
}

private final class InMemoryVaultBookmarkStore: VaultBookmarkStoring {
    private var bookmark: Data?

    init(bookmark: Data?) {
        self.bookmark = bookmark
    }

    func loadVaultRootBookmark() -> Data? {
        bookmark
    }

    func saveVaultRootBookmark(_ bookmark: Data) {
        self.bookmark = bookmark
    }

    func clearVaultRootBookmark() {
        bookmark = nil
    }
}

private func eventually(
    timeoutNanoseconds: UInt64,
    pollIntervalNanoseconds: UInt64 = 20_000_000,
    condition: @escaping @Sendable () async -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while DispatchTime.now().uptimeNanoseconds < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }

    throw TimeoutError()
}

private struct TimeoutError: Error {}
