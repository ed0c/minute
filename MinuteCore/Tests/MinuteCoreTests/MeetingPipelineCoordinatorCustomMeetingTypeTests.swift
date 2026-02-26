import Foundation
import Testing
@testable import MinuteCore

struct MeetingPipelineCoordinatorCustomMeetingTypeTests {
    @Test
    func execute_manualCustomSelection_passesResolvedCustomPromptBundleToSummarization() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let custom = PromptLibraryFixture.customDefinition(
            typeId: "custom-customer-discovery",
            displayName: "Customer Discovery",
            promptComponents: PromptLibraryFixture.promptComponents(
                objective: "Summarize customer discovery findings.",
                summaryFocus: "Prioritize customer pain points and owner next steps."
            )
        )
        let library = PromptLibraryFixture.defaultLibraryWithCustom(custom: custom)
        let summarizationService = CapturingSummarizationService()
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationService: summarizationService,
            library: library
        )

        let context = try makePipelineContext(
            meetingTypeSelection: MeetingTypeSelection(selectionMode: .manual, selectedTypeId: custom.typeId),
            fallbackMeetingType: .general
        )

        _ = try await coordinator.execute(context: context)

        let captured = await summarizationService.captured
        #expect(captured != nil)
        expectEqual(captured?.resolvedPromptBundle?.typeId, custom.typeId)
        expectEqual(captured?.resolvedPromptBundle?.sourceKind, .custom)
        #expect(captured?.resolvedPromptBundle?.systemPrompt.contains("Summarize customer discovery findings.") == true)
    }

    @Test
    func execute_autodetectWithCustomCandidate_usesResolvedCustomBundle() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let custom = PromptLibraryFixture.customDefinition(
            typeId: "custom-customer-discovery",
            displayName: "Customer Discovery",
            autodetectEligible: true,
            promptComponents: PromptLibraryFixture.promptComponents(
                objective: "Summarize customer discovery findings.",
                summaryFocus: "Prioritize customer pain points and owner next steps."
            ),
            classifierProfile: PromptLibraryFixture.classifierProfile(
                label: "Customer Discovery",
                strongSignals: ["customer interviews", "pain points"]
            )
        )
        let library = PromptLibraryFixture.defaultLibraryWithCustom(custom: custom)
        let summarizationService = CapturingSummarizationService(
            dynamicClassificationTypeID: custom.typeId
        )
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationService: summarizationService,
            library: library
        )

        let context = try makePipelineContext(
            meetingTypeSelection: MeetingTypeSelection(selectionMode: .autodetect, selectedTypeId: MeetingType.autodetect.rawValue),
            fallbackMeetingType: .autodetect
        )

        _ = try await coordinator.execute(context: context)

        let captured = await summarizationService.captured
        expectEqual(captured?.resolvedPromptBundle?.typeId, custom.typeId)
        expectEqual(captured?.resolvedPromptBundle?.sourceKind, .custom)
    }

    @Test
    func execute_manualCustomSelection_omitsDisabledSummarySectionsInRenderedNote() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let custom = PromptLibraryFixture.customDefinition(
            typeId: "custom-product-sync",
            displayName: "Product Sync",
            promptComponents: PromptLibraryFixture.promptComponents(
                objective: "Summarize product sync outcomes.",
                summaryFocus: "Capture key actions and context.",
                decisionRulesEnabled: false,
                actionItemRulesEnabled: true,
                openQuestionRulesEnabled: false,
                keyPointRulesEnabled: true
            )
        )
        let library = PromptLibraryFixture.defaultLibraryWithCustom(custom: custom)
        let summarizationService = CapturingSummarizationService()
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationService: summarizationService,
            library: library
        )
        let context = try makePipelineContext(
            meetingTypeSelection: MeetingTypeSelection(selectionMode: .manual, selectedTypeId: custom.typeId),
            fallbackMeetingType: .general
        )

        let outputs = try await coordinator.execute(context: context)
        let noteBody = try String(contentsOf: outputs.noteURL, encoding: .utf8)

        #expect(!noteBody.contains("## Decisions"))
        #expect(noteBody.contains("## Action Items"))
        #expect(!noteBody.contains("## Open Questions"))
        #expect(noteBody.contains("## Key Points"))
    }

    @Test
    func execute_whenManualSelectionReferencesDeletedCustomType_throwsInvalidSelection() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let deletedCustom = PromptLibraryFixture.customDefinition(
            typeId: "custom-removed-type",
            displayName: "Removed Type",
            status: .deleted
        )
        let library = PromptLibraryFixture.defaultLibraryWithCustom(custom: deletedCustom)
        let summarizationService = CapturingSummarizationService()
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationService: summarizationService,
            library: library
        )

        let context = try makePipelineContext(
            meetingTypeSelection: MeetingTypeSelection(selectionMode: .manual, selectedTypeId: deletedCustom.typeId),
            fallbackMeetingType: .general
        )

        do {
            _ = try await coordinator.execute(context: context)
            Issue.record("Expected stale custom selection to fail")
        } catch let error as MinuteError {
            if case .invalidMeetingTypeSelection = error {
                #expect(Bool(true))
            } else {
                Issue.record("Expected invalidMeetingTypeSelection, got \(error)")
            }
        }
    }

    @Test
    func execute_whenPromptResolverThrowsUnexpectedError_rethrowsOriginalError() async throws {
        let vaultRootURL = try makeTemporaryVault()
        defer { try? FileManager.default.removeItem(at: vaultRootURL) }

        let summarizationService = CapturingSummarizationService()
        let coordinator = makeCoordinator(
            vaultRootURL: vaultRootURL,
            summarizationService: summarizationService,
            library: .default,
            promptBundleResolver: ThrowingPromptBundleResolver()
        )

        let context = try makePipelineContext(
            meetingTypeSelection: MeetingTypeSelection(selectionMode: .manual, selectedTypeId: MeetingType.general.rawValue),
            fallbackMeetingType: .general
        )

        do {
            _ = try await coordinator.execute(context: context)
            Issue.record("Expected prompt resolver failure")
        } catch let error as PipelinePromptResolverInjectedError {
            #expect(error == .injected)
        } catch {
            Issue.record("Expected PipelinePromptResolverInjectedError, got \(error)")
        }
    }
}

private struct CapturedSummarizeCall: Sendable {
    var resolvedPromptBundle: ResolvedPromptBundle?
}

private final class CapturingSummarizationService: SummarizationServicing, @unchecked Sendable {
    private let state = CapturingSummarizationState()
    private let dynamicClassificationTypeID: String?

    init(dynamicClassificationTypeID: String? = nil) {
        self.dynamicClassificationTypeID = dynamicClassificationTypeID
    }

    var captured: CapturedSummarizeCall? {
        get async {
            await state.lastCall()
        }
    }

    func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) async throws -> String {
        _ = transcript
        _ = meetingDate
        _ = meetingType
        _ = languageProcessing
        _ = outputLanguage
        return validExtractionJSON
    }

    func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> String {
        _ = transcript
        _ = meetingDate
        _ = meetingType
        _ = languageProcessing
        _ = outputLanguage
        await state.store(CapturedSummarizeCall(resolvedPromptBundle: resolvedPromptBundle))
        return validExtractionJSON
    }

    func classify(transcript: String) async throws -> MeetingType {
        _ = transcript
        return .general
    }

    func classify(
        transcript: String,
        candidates: [MeetingTypeClassifierCandidate],
        fallbackTypeID: String
    ) async throws -> String {
        _ = transcript
        if let dynamicClassificationTypeID,
           candidates.contains(where: { $0.typeId == dynamicClassificationTypeID }) {
            return dynamicClassificationTypeID
        }
        return fallbackTypeID
    }

    func repairJSON(_ invalidJSON: String) async throws -> String {
        invalidJSON
    }
}

private actor CapturingSummarizationState {
    private var call: CapturedSummarizeCall?

    func store(_ call: CapturedSummarizeCall) {
        self.call = call
    }

    func lastCall() -> CapturedSummarizeCall? {
        call
    }
}

private struct PipelineCustomTypeTranscriptionService: TranscriptionServicing {
    func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        _ = wavURL
        return TranscriptionResult(
            text: "Transcript",
            segments: [TranscriptSegment(startSeconds: 0, endSeconds: 1, text: "Transcript")]
        )
    }
}

private struct PipelineCustomTypeDiarizationService: DiarizationServicing {
    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        _ = wavURL
        _ = embeddingExportURL
        return []
    }
}

private enum PipelinePromptResolverInjectedError: Error, Equatable {
    case injected
}

private struct ThrowingPromptBundleResolver: ResolvedPromptBundleResolving {
    func resolvePromptBundle(
        library: MeetingTypeLibrary,
        selection: MeetingTypeSelection,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        autodetectResolvedTypeID: String?
    ) throws -> ResolvedPromptBundle {
        _ = library
        _ = selection
        _ = languageProcessing
        _ = outputLanguage
        _ = autodetectResolvedTypeID
        throw PipelinePromptResolverInjectedError.injected
    }
}

private struct PipelineCustomTypeModelManager: ModelManaging {
    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        progress?(ModelDownloadProgress(fractionCompleted: 1, label: "ready"))
    }

    func validateModels() async throws -> ModelValidationResult {
        ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
    }

    func removeModels(withIDs ids: [String]) async throws {
        _ = ids
    }
}

private struct PipelineCustomTypeVaultWriter: VaultWriting {
    func writeAtomically(data: Data, to destinationURL: URL) throws {
        try ensureDirectoryExists(destinationURL.deletingLastPathComponent())
        try data.write(to: destinationURL, options: [.atomic])
    }

    func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private final class PipelineCustomTypeBookmarkStore: VaultBookmarkStoring {
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

private func makeCoordinator(
    vaultRootURL: URL,
    summarizationService: CapturingSummarizationService,
    library: MeetingTypeLibrary,
    promptBundleResolver: any ResolvedPromptBundleResolving = ResolvedPromptBundleResolver()
) -> MeetingPipelineCoordinator {
    let bookmark = try? VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
    let bookmarkStore = PipelineCustomTypeBookmarkStore(bookmark: bookmark)
    let vaultAccess = VaultAccess(bookmarkStore: bookmarkStore)

    return MeetingPipelineCoordinator(
        transcriptionService: PipelineCustomTypeTranscriptionService(),
        diarizationService: PipelineCustomTypeDiarizationService(),
        summarizationServiceProvider: { summarizationService },
        modelManager: PipelineCustomTypeModelManager(),
        meetingTypeLibraryStore: MockMeetingTypeLibraryStore(library: library),
        promptBundleResolver: promptBundleResolver,
        vaultAccess: vaultAccess,
        vaultWriter: PipelineCustomTypeVaultWriter()
    )
}

private func makePipelineContext(
    meetingTypeSelection: MeetingTypeSelection,
    fallbackMeetingType: MeetingType
) throws -> PipelineContext {
    let directory = try makeTemporaryVault()
    let audioURL = directory.appendingPathComponent("input.wav")
    try Data([0x00, 0x01, 0x02]).write(to: audioURL, options: [.atomic])

    return PipelineContext(
        vaultFolders: MeetingFileContract.VaultFolders(),
        audioTempURL: audioURL,
        audioDurationSeconds: 3,
        startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        stoppedAt: Date(timeIntervalSince1970: 1_700_000_003),
        workingDirectoryURL: directory,
        saveAudio: false,
        saveTranscript: false,
        meetingTypeSelection: meetingTypeSelection,
        meetingType: fallbackMeetingType
    )
}

private func makeTemporaryVault() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-custom-type-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private let validExtractionJSON = """
{
  "title": "Customer Discovery",
  "date": "2026-02-23",
  "summary": "Summary.",
  "decisions": [],
  "action_items": [],
  "open_questions": [],
  "key_points": []
}
"""
