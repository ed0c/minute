import Foundation
import Testing
@testable import Minute
@testable import MinuteCore

@MainActor
struct MeetingPipelineViewModelMeetingTypeSafetyTests {
    @Test
    func staleSelectionFromPreferences_setsWarningState() throws {
        let suite = "MeetingPipelineViewModelMeetingTypeSafetyTests.warning.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let stageStore = StagePreferencesStore(defaults: defaults)
        stageStore.save(
            StagePreferences(
                meetingTypeID: "custom-missing-type",
                languageProcessing: .autoToEnglish,
                microphoneEnabled: true,
                systemAudioEnabled: true
            )
        )

        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")
        let model = try makeModel(stagePreferencesStore: stageStore, meetingTypeLibraryStore: store)

        #expect(model.isSelectedMeetingTypeAvailable == false)
        #expect(model.selectedMeetingTypeWarningMessage != nil)
    }

    @Test
    func processWithStaleSelection_blocksWithInvalidMeetingTypeError() async throws {
        let suite = "MeetingPipelineViewModelMeetingTypeSafetyTests.process.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let stageStore = StagePreferencesStore(defaults: defaults)
        stageStore.save(
            StagePreferences(
                meetingTypeID: "custom-deleted-type",
                languageProcessing: .autoToEnglish,
                microphoneEnabled: true,
                systemAudioEnabled: true
            )
        )

        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")
        let model = try makeModel(stagePreferencesStore: stageStore, meetingTypeLibraryStore: store)

        model.send(.importFile(URL(fileURLWithPath: "/tmp/input.wav")))
        try await eventually(timeoutNanoseconds: 2_000_000_000) {
            if case .recorded = model.state { return true }
            return false
        }

        model.send(.process)
        try await eventually(timeoutNanoseconds: 2_000_000_000) {
            if case .failed(let error, _) = model.state {
                return error == .invalidMeetingTypeSelection
            }
            return false
        }
    }

    @Test
    func deleteCustomType_requiresConfirmationAndRemovesType() throws {
        let defaults = UserDefaults(suiteName: "MeetingTypeDeleteConfirmation.\(UUID().uuidString)")!
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")
        let model = MeetingTypesSettingsViewModel(store: store)

        model.startCreateCustomType()
        model.draftDisplayName = "Delete Candidate"
        model.draftObjective = "Objective"
        model.draftSummaryFocus = "Summary"
        model.saveDraft()

        #expect(model.selectedDefinition?.source == .custom)

        model.requestDeleteSelectedCustomType()
        #expect(model.isDeleteConfirmationPresented)

        let selectedTypeID = model.selectedTypeID
        model.confirmDeleteSelectedCustomType()

        #expect(model.isDeleteConfirmationPresented == false)
        #expect(model.meetingTypes.contains(where: { $0.typeId == selectedTypeID }) == false)
    }

    private func makeModel(
        stagePreferencesStore: StagePreferencesStore,
        meetingTypeLibraryStore: MeetingTypeLibraryStore
    ) throws -> MeetingPipelineViewModel {
        let vaultRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-meeting-safety-vault-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultRoot, withIntermediateDirectories: true)
        let bookmark = try VaultAccess.makeBookmarkData(forVaultRootURL: vaultRoot)
        let bookmarkStore = InMemoryVaultBookmarkStore(bookmark: bookmark)
        let vaultAccess = VaultAccess(bookmarkStore: bookmarkStore)

        let coordinator = MeetingPipelineCoordinator(
            transcriptionService: MockTranscriptionService(),
            diarizationService: MockDiarizationService(),
            summarizationServiceProvider: { MockSummarizationService() },
            modelManager: MockModelManager(),
            meetingTypeLibraryStore: meetingTypeLibraryStore,
            promptBundleResolver: ResolvedPromptBundleResolver(),
            vaultAccess: vaultAccess,
            vaultWriter: DefaultVaultWriter()
        )

        return MeetingPipelineViewModel(
            audioService: MockAudioService(),
            mediaImportService: MockMediaImportService(),
            recoveryService: MockRecordingRecoveryService(),
            pipelineCoordinator: coordinator,
            screenContextCaptureService: ScreenContextCaptureService(inferencer: MockScreenContextInferenceService()),
            screenContextVideoExtractor: ScreenContextVideoFrameExtractor(inferencer: MockScreenContextInferenceService()),
            screenContextSettingsStore: ScreenContextSettingsStore(),
            vaultAccess: vaultAccess,
            recordingPermissions: .alwaysGranted(),
            stagePreferencesStore: stagePreferencesStore,
            meetingTypeLibraryStore: meetingTypeLibraryStore
        )
    }
}
