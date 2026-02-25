import Foundation
import os

public actor MeetingPipelineCoordinator {
    private let transcriptionService: any TranscriptionServicing
    private let diarizationService: any DiarizationServicing
    private let audioLoudnessNormalizer: any AudioLoudnessNormalizing
    private let summarizationServiceProvider: @Sendable () -> any SummarizationServicing
    private let modelManager: any ModelManaging
    private let meetingTypeLibraryStore: any MeetingTypeLibraryStoring
    private let promptBundleResolver: any ResolvedPromptBundleResolving
    private let vaultAccess: VaultAccess
    private let vaultWriter: any VaultWriting
    private let speakerProfileStore: SpeakerProfileStore
    private let meetingSpeakerEmbeddingCache: MeetingSpeakerEmbeddingCache
    private let dateProvider: @Sendable () -> Date

    private let logger = Logger(subsystem: "roblibob.Minute", category: "pipeline")

    public init(
        transcriptionService: some TranscriptionServicing,
        diarizationService: some DiarizationServicing,
        summarizationServiceProvider: @escaping @Sendable () -> any SummarizationServicing,
        audioLoudnessNormalizer: any AudioLoudnessNormalizing = NoOpAudioLoudnessNormalizer(),
        modelManager: some ModelManaging,
        meetingTypeLibraryStore: any MeetingTypeLibraryStoring = MeetingTypeLibraryStore(),
        promptBundleResolver: any ResolvedPromptBundleResolving = ResolvedPromptBundleResolver(),
        vaultAccess: VaultAccess,
        vaultWriter: some VaultWriting,
        speakerProfileStore: SpeakerProfileStore = SpeakerProfileStore(),
        meetingSpeakerEmbeddingCache: MeetingSpeakerEmbeddingCache = MeetingSpeakerEmbeddingCache(),
        dateProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.transcriptionService = transcriptionService
        self.diarizationService = diarizationService
        self.audioLoudnessNormalizer = audioLoudnessNormalizer
        self.summarizationServiceProvider = summarizationServiceProvider
        self.modelManager = modelManager
        self.meetingTypeLibraryStore = meetingTypeLibraryStore
        self.promptBundleResolver = promptBundleResolver
        self.vaultAccess = vaultAccess
        self.vaultWriter = vaultWriter
        self.speakerProfileStore = speakerProfileStore
        self.meetingSpeakerEmbeddingCache = meetingSpeakerEmbeddingCache
        self.dateProvider = dateProvider
    }

    public func execute(
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)? = nil
    ) async throws -> PipelineResult {
        do {
            var context = context
            try Task.checkCancellation()
            await attemptRecoverMissingContractAudioIfNeeded(context: context)

            progress?(.downloadingModels(fractionCompleted: 0))
            try await modelManager.ensureModelsPresent { update in
                let clamped = min(max(update.fractionCompleted, 0), 1)
                progress?(.downloadingModels(fractionCompleted: clamped * 0.1))
            }

            try Task.checkCancellation()
            progress?(.transcribing(fractionCompleted: 0.1))

            if context.normalizeAnalysisAudio {
                do {
                    let normalizedURL = try await audioLoudnessNormalizer.normalizeForAnalysis(
                        inputURL: context.audioTempURL,
                        workingDirectoryURL: context.workingDirectoryURL
                    )
                    context.analysisAudioURL = normalizedURL
                } catch {
                    // Normalization is a quality improvement. If ffmpeg is missing or input audio is unreadable,
                    // proceed with the original analysis audio rather than failing the whole pipeline.
                    logger.error("Analysis audio normalization failed; proceeding without normalization: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
                }
            }

            // Capture the canonical audio bytes early (analysis normalization must not affect vault output).
            // This also decouples the vault write from the temp-file lifetime across async boundaries.
            let originalAudioData: Data?
            if context.saveAudio {
                originalAudioData = try Data(contentsOf: context.audioTempURL)
            } else {
                originalAudioData = nil
            }

            let transcription: TranscriptionResult
            if let override = context.transcriptionOverride, !override.text.isEmpty {
                transcription = override
            } else if let vocabularyService = transcriptionService as? (any VocabularyBoostingTranscriptionServicing) {
                transcription = try await vocabularyService.transcribe(
                    wavURL: context.analysisAudioURL,
                    vocabulary: context.transcriptionVocabulary
                )
            } else {
                transcription = try await transcriptionService.transcribe(wavURL: context.analysisAudioURL)
            }
            let embeddingExportURL = context.knownSpeakerSuggestionsEnabled
                ? context.workingDirectoryURL.appendingPathComponent("diarization-embeddings.json")
                : nil

            let diarizationSegments = await diarizeIfPossible(
                wavURL: context.analysisAudioURL,
                embeddingExportURL: embeddingExportURL
            )
            let attributedSegments = SpeakerAttribution.attribute(
                transcriptSegments: transcription.segments,
                speakerSegments: diarizationSegments
            )
            let timelineSegments: [AttributedTranscriptSegment]
            if attributedSegments.isEmpty {
                timelineSegments = transcription.segments.map { segment in
                    AttributedTranscriptSegment(
                        startSeconds: segment.startSeconds,
                        endSeconds: segment.endSeconds,
                        speakerId: 0,
                        text: segment.text
                    )
                }
            } else {
                timelineSegments = attributedSegments
            }
            let timelineEntries = MeetingTimelineBuilder.build(
                transcriptSegments: timelineSegments,
                screenEvents: context.screenContextEvents
            )
            let timelineText = MeetingTimelineRenderer().render(entries: timelineEntries)

            try Task.checkCancellation()
            progress?(.summarizing(fractionCompleted: 0.5))

            let summarizationService = summarizationServiceProvider()
            let meetingDate = context.startedAt

            let meetingTypeLibrary = meetingTypeLibraryStore.load()
            var effectiveType = context.meetingType
            var autodetectResolvedTypeID: String? = nil
            if context.meetingTypeSelection.selectionMode == .autodetect {
                let fallbackTypeID = MeetingType.general.rawValue
                let classifierCandidates = makeClassifierCandidates(library: meetingTypeLibrary)
                let resolvedTypeID = try await summarizationService.classify(
                    transcript: timelineText,
                    candidates: classifierCandidates,
                    fallbackTypeID: fallbackTypeID
                )

                autodetectResolvedTypeID = resolvedTypeID
                effectiveType = MeetingType(rawValue: resolvedTypeID) ?? .general
                logger.info("Autodetected meeting type ID: \(resolvedTypeID, privacy: .public)")
            } else {
                let selectedTypeID = context.meetingTypeSelection.selectedTypeId
                effectiveType = MeetingType(rawValue: selectedTypeID) ?? context.meetingType
            }

            let resolvedPromptBundle: ResolvedPromptBundle
            do {
                resolvedPromptBundle = try promptBundleResolver.resolvePromptBundle(
                    library: meetingTypeLibrary,
                    selection: context.meetingTypeSelection,
                    languageProcessing: context.languageProcessing,
                    outputLanguage: context.outputLanguage,
                    autodetectResolvedTypeID: autodetectResolvedTypeID
                )
            } catch {
                logger.error("Prompt bundle resolution failed: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
                throw MinuteError.invalidMeetingTypeSelection
            }

            let rawJSON = try await summarizationService.summarize(
                transcript: timelineText,
                meetingDate: meetingDate,
                meetingType: effectiveType,
                languageProcessing: context.languageProcessing,
                outputLanguage: context.outputLanguage,
                resolvedPromptBundle: resolvedPromptBundle
            )
            var extraction = try await decodeOrRepairExtraction(
                rawJSON: rawJSON,
                meetingDate: meetingDate,
                summarizationService: summarizationService
            )
            extraction.meetingType = effectiveType

            try Task.checkCancellation()
            progress?(.writing(fractionCompleted: 0.85, extraction: extraction))

            let suggestionResult = await suggestKnownSpeakersFrontmatterIfEnabled(
                context: context,
                diarizationSegments: diarizationSegments,
                embeddingExportURL: embeddingExportURL
            )

            let participantFrontmatter = suggestionResult?.frontmatter

            let outputs = try writeOutputsToVault(
                context: context,
                extraction: extraction,
                transcription: transcription,
                attributedSegments: attributedSegments,
                originalAudioData: originalAudioData,
                participantFrontmatter: participantFrontmatter
            )

            if let embeddingsBySpeakerID = suggestionResult?.embeddingsBySpeakerID, !embeddingsBySpeakerID.isEmpty {
                // Persist in app-owned storage (never the vault) for later explicit enrollment.
                try await meetingSpeakerEmbeddingCache.upsert(
                    meetingKey: outputs.noteURL.path,
                    embeddingsBySpeakerID: embeddingsBySpeakerID,
                    embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
                )
            }

            cleanupTemporaryArtifacts(for: context)
            return outputs
        } catch is CancellationError {
            logger.info("Pipeline cancelled")
            throw CancellationError()
        } catch {
            logger.error("Pipeline failed: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
            // Keep capture audio on failures so retry can reuse the same context safely.
            cleanupTemporaryArtifacts(for: context, policy: .workingDirectoryOnly)
            throw error
        }
    }

    private func makeClassifierCandidates(library: MeetingTypeLibrary) -> [MeetingTypeClassifierCandidate] {
        var candidates: [MeetingTypeClassifierCandidate] = []
        candidates.reserveCapacity(library.activeDefinitions.count)

        for definition in library.activeDefinitions {
            if definition.typeId == MeetingType.autodetect.rawValue {
                continue
            }

            if definition.source == .custom && !definition.autodetectEligible {
                continue
            }

            let fallbackSignals = [definition.displayName]
            let profileSignals = definition.classifierProfile?.strongSignals ?? []
            let strongSignals = (profileSignals.isEmpty ? fallbackSignals : profileSignals)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let label = (definition.classifierProfile?.label ?? definition.displayName)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }

            candidates.append(
                MeetingTypeClassifierCandidate(
                    typeId: definition.typeId,
                    label: label,
                    strongSignals: strongSignals
                )
            )
        }

        if !candidates.contains(where: { $0.typeId == MeetingType.general.rawValue }) {
            candidates.append(
                MeetingTypeClassifierCandidate(
                    typeId: MeetingType.general.rawValue,
                    label: MeetingType.general.displayName,
                    strongSignals: ["general business discussion"]
                )
            )
        }

        return candidates
    }

    private func decodeOrRepairExtraction(
        rawJSON: String,
        meetingDate: Date,
        summarizationService: any SummarizationServicing
    ) async throws -> MeetingExtraction {
        do {
            let decoded = try decodeExtractionStrict(from: rawJSON)
            return MeetingExtractionValidation.validated(decoded, recordingDate: meetingDate)
        } catch {
            logger.info("Extraction JSON invalid; attempting repair")

            let repaired = try await summarizationService.repairJSON(rawJSON)

            do {
                let decoded = try decodeExtractionStrict(from: repaired)
                return MeetingExtractionValidation.validated(decoded, recordingDate: meetingDate)
            } catch {
                logger.error("Extraction still invalid after repair; proceeding with fallback")
                return MeetingExtractionValidation.fallback(recordingDate: meetingDate)
            }
        }
    }

    /// Strictly decodes the first top-level JSON object and rejects any non-whitespace outside it.
    private func decodeExtractionStrict(from rawOutput: String) throws -> MeetingExtraction {
        let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let extracted = JSONFirstObjectExtractor.extractFirstJSONObject(from: trimmed) else {
            throw MinuteError.jsonInvalid
        }

        do {
            return try JSONDecoder().decode(MeetingExtraction.self, from: Data(extracted.jsonObject.utf8))
        } catch {
            throw MinuteError.jsonInvalid
        }
    }

    private func writeOutputsToVault(
        context: PipelineContext,
        extraction: MeetingExtraction,
        transcription: TranscriptionResult,
        attributedSegments: [AttributedTranscriptSegment],
        originalAudioData: Data?,
        participantFrontmatter: MeetingParticipantFrontmatter?
    ) throws -> PipelineResult {
        let recordingDate = context.startedAt
        // Use extraction.date if parseable, otherwise fall back to the recording date.
        let meetingDate = MinuteISODate.parse(extraction.date) ?? recordingDate
        let meetingDateISO = MinuteISODate.format(meetingDate)

        let contract = MeetingFileContract(folders: context.vaultFolders)
        let noteRelativePath = contract.noteRelativePath(date: recordingDate, title: extraction.title)
        let audioRelativePath = context.saveAudio ? contract.audioRelativePath(date: recordingDate, title: extraction.title) : nil
        let transcriptRelativePath = context.saveTranscript ? contract.transcriptRelativePath(date: recordingDate, title: extraction.title) : nil

        let transcriptData: Data?
        if transcriptRelativePath != nil {
            let speakerDisplayNames = participantFrontmatter?.speakerMap ?? [:]
            let transcriptMarkdown = TranscriptMarkdownRenderer().render(
                title: extraction.title,
                dateISO: meetingDateISO,
                transcript: transcription.text,
                attributedSegments: attributedSegments,
                speakerDisplayNames: speakerDisplayNames
            )
            transcriptData = Data(transcriptMarkdown.utf8)
        } else {
            transcriptData = nil
        }

        return try vaultAccess.withVaultAccess { vaultRootURL in
            let resolvedPaths = resolveOutputPaths(
                vaultRootURL: vaultRootURL,
                noteRelativePath: noteRelativePath,
                audioRelativePath: audioRelativePath,
                transcriptRelativePath: transcriptRelativePath
            )

            let processedDateTime = MeetingNoteDateFormatter.format(dateProvider())
            let noteMarkdown = MarkdownRenderer().render(
                extraction: extraction,
                noteDateTime: processedDateTime,
                audioDurationSeconds: context.audioDurationSeconds,
                audioRelativePath: resolvedPaths.audioRelativePath,
                transcriptRelativePath: resolvedPaths.transcriptRelativePath,
                participantFrontmatter: participantFrontmatter
            )
            let noteData = Data(noteMarkdown.utf8)

            let noteURL = vaultRootURL.appendingPathComponent(resolvedPaths.noteRelativePath)

            // Transcript
            if let transcriptRelativePath = resolvedPaths.transcriptRelativePath, let transcriptData {
                let transcriptURL = vaultRootURL.appendingPathComponent(transcriptRelativePath)
                try vaultWriter.writeAtomically(data: transcriptData, to: transcriptURL)
            }

            // Note
            try vaultWriter.writeAtomically(data: noteData, to: noteURL)

            // Audio
            let audioURL: URL?
            if let audioRelativePath = resolvedPaths.audioRelativePath {
                guard let audioData = originalAudioData else {
                    throw MinuteError.audioExportFailed
                }
                let resolvedURL = vaultRootURL.appendingPathComponent(audioRelativePath)
                try vaultWriter.writeAtomically(data: audioData, to: resolvedURL)
                audioURL = resolvedURL
            } else {
                audioURL = nil
            }

            return PipelineResult(noteURL: noteURL, audioURL: audioURL)
        }
    }

    private func resolveOutputPaths(
        vaultRootURL: URL,
        noteRelativePath: String,
        audioRelativePath: String?,
        transcriptRelativePath: String?
    ) -> (noteRelativePath: String, audioRelativePath: String?, transcriptRelativePath: String?) {
        let fileManager = FileManager.default

        func normalizeRelativePath(_ relativePath: String) -> String {
            VaultPathNormalizer
                .normalizedRelativeComponents(relativePath)
                .joined(separator: "/")
        }

        let noteRelativePath = normalizeRelativePath(noteRelativePath)
        let audioRelativePath = audioRelativePath.map(normalizeRelativePath)
        let transcriptRelativePath = transcriptRelativePath.map(normalizeRelativePath)

        func withSuffix(_ relativePath: String, suffix: String) -> String {
            let ns = relativePath as NSString
            let ext = ns.pathExtension
            let base = ns.deletingPathExtension
            return ext.isEmpty ? base + suffix : base + suffix + "." + ext
        }

        func exists(_ relativePath: String?) -> Bool {
            guard let relativePath else { return false }
            return fileManager.fileExists(atPath: vaultRootURL.appendingPathComponent(relativePath).path)
        }

        // Fast path: no collision.
        if !exists(noteRelativePath) {
            return (noteRelativePath, audioRelativePath, transcriptRelativePath)
        }

        // Collision: choose a stable, user-readable suffix.
        for index in 2...99 {
            let suffix = " (\(index))"
            let candidateNote = withSuffix(noteRelativePath, suffix: suffix)
            let candidateAudio = audioRelativePath.map { withSuffix($0, suffix: suffix) }
            let candidateTranscript = transcriptRelativePath.map { withSuffix($0, suffix: suffix) }

            if !exists(candidateNote), !exists(candidateAudio), !exists(candidateTranscript) {
                return (candidateNote, candidateAudio, candidateTranscript)
            }
        }

        // As a last resort, fall back to the original path (writer will overwrite or throw depending on implementation).
        return (noteRelativePath, audioRelativePath, transcriptRelativePath)
    }

    private func diarizeIfPossible(wavURL: URL, embeddingExportURL: URL?) async -> [SpeakerSegment] {
        do {
            return try await diarizationService.diarize(wavURL: wavURL, embeddingExportURL: embeddingExportURL)
        } catch {
            logger.error("Diarization failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            return []
        }
    }

    private func suggestKnownSpeakersFrontmatterIfEnabled(
        context: PipelineContext,
        diarizationSegments: [SpeakerSegment],
        embeddingExportURL: URL?
    ) async -> KnownSpeakerSuggestionResult? {
        guard context.knownSpeakerSuggestionsEnabled else { return nil }
        guard let embeddingExportURL else { return nil }

        do {
            let entries = try OfflineDiarizerEmbeddingExport.load(from: embeddingExportURL)
            let aggregated = try OfflineDiarizerEmbeddingExport.aggregateByCluster(entries: entries)
            if aggregated.isEmpty { return nil }

            let meetingSpeakerOrder = SpeakerOrdering.orderedSpeakerIDs(from: diarizationSegments)
            let overlapByClusterSpeakerID = Self.overlapSecondsByClusterSpeakerID(
                entries: entries,
                diarizationSegments: diarizationSegments
            )

            // Best-effort mapping: infer which diarization `speakerId` each embedding `cluster` corresponds to.
            // This avoids incorrect assignments when clusters and speaker IDs do not sort-align.
            let clusterToSpeakerId = Self.bestSpeakerIDByCluster(overlapByClusterSpeakerID)
            let bestClusterBySpeakerID = Self.bestClusterBySpeakerID(
                overlapByClusterSpeakerID,
                clusterToSpeakerId: clusterToSpeakerId
            )

            var embeddingsBySpeakerID: [Int: [Float]] = [:]
            embeddingsBySpeakerID.reserveCapacity(aggregated.count)
            for item in aggregated {
                guard let speakerId = clusterToSpeakerId[item.speakerCluster] else {
                    // If we can’t map a cluster into the diarization speaker-id space, skip it.
                    // This avoids introducing 0-based cluster IDs into speaker-facing IDs.
                    continue
                }
                if let preferredCluster = bestClusterBySpeakerID[speakerId], preferredCluster != item.speakerCluster {
                    continue
                }
                embeddingsBySpeakerID[speakerId] = item.embedding
            }

            let profiles = try await speakerProfileStore.listProfiles()
            if profiles.isEmpty {
                return KnownSpeakerSuggestionResult(
                    frontmatter: nil,
                    embeddingsBySpeakerID: embeddingsBySpeakerID
                )
            }

            let matcher = SpeakerEmbeddingMatcher()

            var speakerMap: [Int: String] = [:]
            for item in aggregated {
                guard let speakerId = clusterToSpeakerId[item.speakerCluster] else {
                    continue
                }
                if let preferredCluster = bestClusterBySpeakerID[speakerId], preferredCluster != item.speakerCluster {
                    continue
                }
                if let match = try matcher.bestMatch(
                    embedding: item.embedding,
                    candidates: profiles,
                    embeddingModelVersion: SpeakerEmbeddingModelVersions.fluidAudioOfflineVbx256
                ) {
                    speakerMap[speakerId] = match.profile.name
                }
            }

            let participants = Self.participantsOrderedBySpeakerOrder(
                speakerOrder: meetingSpeakerOrder,
                speakerMap: speakerMap
            )
            let frontmatter: MeetingParticipantFrontmatter?
            if participants.isEmpty && speakerMap.isEmpty {
                frontmatter = nil
            } else {
                let speakerOrder = meetingSpeakerOrder
                frontmatter = MeetingParticipantFrontmatter(
                    participants: participants,
                    speakerMap: speakerMap,
                    speakerOrder: speakerOrder
                )
            }

            return KnownSpeakerSuggestionResult(frontmatter: frontmatter, embeddingsBySpeakerID: embeddingsBySpeakerID)
        } catch {
            // Suggestions are best-effort: never fail the pipeline.
            logger.error("Known-speaker suggestion step failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            return nil
        }
    }

    private struct KnownSpeakerSuggestionResult: Sendable {
        var frontmatter: MeetingParticipantFrontmatter?
        var embeddingsBySpeakerID: [Int: [Float]]
    }

    private static func overlapSecondsByClusterSpeakerID(
        entries: [OfflineDiarizerEmbeddingExport.Entry],
        diarizationSegments: [SpeakerSegment]
    ) -> [Int: [Int: Double]] {
        guard !entries.isEmpty, !diarizationSegments.isEmpty else { return [:] }

        var overlaps: [Int: [Int: Double]] = [:]

        for entry in entries {
            let start = entry.startTime
            let end = entry.endTime
            guard end > start else { continue }

            for seg in diarizationSegments {
                let overlapStart = max(start, seg.startSeconds)
                let overlapEnd = min(end, seg.endSeconds)
                let overlap = overlapEnd - overlapStart
                guard overlap > 0 else { continue }

                overlaps[entry.cluster, default: [:]][seg.speakerId, default: 0] += overlap
            }
        }

        return overlaps
    }

    private static func bestSpeakerIDByCluster(_ overlaps: [Int: [Int: Double]]) -> [Int: Int] {
        var result: [Int: Int] = [:]
        result.reserveCapacity(overlaps.count)

        for cluster in overlaps.keys.sorted() {
            guard let speakerOverlaps = overlaps[cluster], !speakerOverlaps.isEmpty else { continue }

            let best = speakerOverlaps
                .sorted { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value > rhs.value }
                    return lhs.key < rhs.key
                }
                .first

            if let best {
                result[cluster] = best.key
            }
        }

        return result
    }

    private static func bestClusterBySpeakerID(
        _ overlaps: [Int: [Int: Double]],
        clusterToSpeakerId: [Int: Int]
    ) -> [Int: Int] {
        // If multiple clusters map to the same speakerId, keep the cluster with the strongest overlap.
        var best: [Int: (cluster: Int, score: Double)] = [:]

        for (cluster, speakerId) in clusterToSpeakerId {
            let score = overlaps[cluster]?[speakerId] ?? 0

            if let existing = best[speakerId] {
                if score > existing.score || (score == existing.score && cluster < existing.cluster) {
                    best[speakerId] = (cluster: cluster, score: score)
                }
            } else {
                best[speakerId] = (cluster: cluster, score: score)
            }
        }

        return best.mapValues { $0.cluster }
    }

    private static func participantsOrderedBySpeakerOrder(
        speakerOrder: [Int],
        speakerMap: [Int: String]
    ) -> [String] {
        guard !speakerMap.isEmpty else { return [] }

        var result: [String] = []
        result.reserveCapacity(speakerMap.count)

        var seenLowercased: Set<String> = []

        for id in speakerOrder {
            guard let raw = speakerMap[id] else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seenLowercased.insert(key).inserted {
                result.append(trimmed)
            }
        }

        if result.count == speakerMap.count {
            return result
        }

        let remaining = speakerMap.values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !seenLowercased.contains($0.lowercased()) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        result.append(contentsOf: remaining)
        return result
    }

    private func attemptRecoverMissingContractAudioIfNeeded(context: PipelineContext) async {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: context.audioTempURL.path) else { return }
        guard context.audioTempURL.lastPathComponent.lowercased() == "contract.wav" else { return }

        let sessionURL = context.audioTempURL.deletingLastPathComponent()
        let captureURL = sessionURL.appendingPathComponent("capture.caf")
        let systemURL = sessionURL.appendingPathComponent("system.caf")
        let hasCapture = fileManager.fileExists(atPath: captureURL.path)

        guard hasCapture else { return }

        let hasSystem = fileManager.fileExists(atPath: systemURL.path)
        logger.info("Audio input missing; attempting to rebuild contract WAV for \(sessionURL.lastPathComponent, privacy: .private(mask: .hash))")

        do {
            if hasSystem {
                try await AudioWavMixer.mixToContractWav(
                    micURL: captureURL,
                    systemURL: systemURL,
                    outputURL: context.audioTempURL
                )
            } else {
                try await AudioWavConverter.convertToContractWav(
                    inputURL: captureURL,
                    outputURL: context.audioTempURL
                )
            }
            try ContractWavVerifier.verifyContractWav(at: context.audioTempURL)
            logger.info("Recovered missing contract WAV for \(sessionURL.lastPathComponent, privacy: .private(mask: .hash))")
        } catch {
            logger.error("Failed to recover missing contract WAV: \(ErrorHandler.debugMessage(for: error), privacy: .private(mask: .hash))")
        }
    }

    private enum ArtifactCleanupPolicy {
        case all
        case workingDirectoryOnly
    }

    private func cleanupTemporaryArtifacts(
        for context: PipelineContext,
        policy: ArtifactCleanupPolicy = .all
    ) {
        let fileManager = FileManager.default
        let tempRootURL = fileManager.temporaryDirectory.standardizedFileURL
        let tempRootPath = tempRootURL.path.hasSuffix("/") ? tempRootURL.path : tempRootURL.path + "/"

        if policy == .all {
            let audioTempDir = context.audioTempURL.deletingLastPathComponent().standardizedFileURL.path
            if audioTempDir.hasPrefix(tempRootPath) {
                try? fileManager.removeItem(atPath: audioTempDir)
            }
        }

        let workingDir = context.workingDirectoryURL.standardizedFileURL.path
        if workingDir.hasPrefix(tempRootPath) {
            try? fileManager.removeItem(atPath: workingDir)
        }
    }
}
