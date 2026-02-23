import Foundation
import MinuteCore
import Testing
@testable import Minute

actor AutoSilenceAudioService: AudioServicing, AudioLevelMetering, AudioCaptureControlling {
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

typealias ContinuousSilenceAudioService = AutoSilenceAudioService

final class InMemoryVaultBookmarkStore: VaultBookmarkStoring {
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

func eventually(
    timeoutNanoseconds: UInt64,
    pollIntervalNanoseconds: UInt64 = 10_000_000,
    condition: @escaping @Sendable () async -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while DispatchTime.now().uptimeNanoseconds < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }

    throw EventuallyTimeoutError()
}

private struct EventuallyTimeoutError: Error {}

struct PipelineViewModelFixtureDependencies {
    var defaults: UserDefaults
    var stagePreferencesStore: StagePreferencesStore
    var coordinator: MeetingPipelineCoordinator
    var viewModelVaultAccess: VaultAccess
}

enum PipelineViewModelFixtureBuilder {
    static func makeDependencies(
        suiteName: String,
        summarizationServiceProvider: @escaping @Sendable () -> any SummarizationServicing = {
            MockSummarizationService()
        }
    ) throws -> PipelineViewModelFixtureDependencies {
        let defaults = try makeIsolatedDefaults(suiteName: suiteName)
        let stagePreferencesStore = StagePreferencesStore(defaults: defaults)
        stagePreferencesStore.clear()

        let coordinatorVaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: nil))
        let viewModelVaultAccess = VaultAccess(bookmarkStore: InMemoryVaultBookmarkStore(bookmark: nil))
        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationServiceProvider: summarizationServiceProvider,
            modelManager: MockModelManager(),
            vaultAccess: coordinatorVaultAccess,
            vaultWriter: DefaultVaultWriter()
        )

        return PipelineViewModelFixtureDependencies(
            defaults: defaults,
            stagePreferencesStore: stagePreferencesStore,
            coordinator: coordinator,
            viewModelVaultAccess: viewModelVaultAccess
        )
    }

    static func makeIsolatedDefaults(suiteName: String) throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
