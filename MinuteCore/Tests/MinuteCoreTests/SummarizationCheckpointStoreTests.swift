import Foundation
import Testing
@testable import MinuteCore

struct SummarizationCheckpointStoreTests {
    @Test
    func saveAndLoadRoundTrip() async throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-checkpoint-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let store = DefaultSummarizationCheckpointStore(baseDirectoryURL: baseURL)
        let checkpointDate = Date(timeIntervalSince1970: 1_700_000_000)
        let state = SummarizationRunState(
            runID: "run-1",
            meetingID: "meeting-1",
            status: .pausedForRetry,
            currentPassIndex: 2,
            totalPassCount: 5,
            lastValidCheckpoint: SummarizationSummaryCheckpoint(
                completedPassIndex: 2,
                summaryJSON: "{\"title\":\"Weekly\"}",
                sourceChunkIDs: ["c1", "c2"],
                updatedAt: checkpointDate
            ),
            passRecords: [
                SummarizationPassRecord(passIndex: 1, chunkID: "c1", status: .completed),
                SummarizationPassRecord(passIndex: 2, chunkID: "c2", status: .completed),
            ]
        )

        try await store.save(state, for: "meeting-1")
        let loaded = try await store.load(meetingID: "meeting-1")

        #expect(loaded == state)
    }

    @Test
    func clearRemovesSavedCheckpoint() async throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-checkpoint-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let store = DefaultSummarizationCheckpointStore(baseDirectoryURL: baseURL)
        let state = SummarizationRunState(
            runID: "run-2",
            meetingID: "meeting-2",
            status: .running,
            currentPassIndex: 1,
            totalPassCount: 3
        )

        try await store.save(state, for: "meeting-2")
        await store.clear(meetingID: "meeting-2")
        let loaded = try await store.load(meetingID: "meeting-2")

        #expect(loaded == nil)
    }

    @Test
    func loadReturnsNilForMissingState() async throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-checkpoint-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let store = DefaultSummarizationCheckpointStore(baseDirectoryURL: baseURL)
        let loaded = try await store.load(meetingID: "missing")
        #expect(loaded == nil)
    }

    @Test
    func saveTracksPerPassCheckpointProgression() async throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-checkpoint-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let store = DefaultSummarizationCheckpointStore(baseDirectoryURL: baseURL)

        let checkpointPass1 = SummarizationSummaryCheckpoint(
            completedPassIndex: 1,
            summaryJSON: "{\"title\":\"Weekly\",\"summary\":\"pass1\"}",
            sourceChunkIDs: ["c1"]
        )
        let checkpointPass2 = SummarizationSummaryCheckpoint(
            completedPassIndex: 2,
            summaryJSON: "{\"title\":\"Weekly\",\"summary\":\"pass2\"}",
            sourceChunkIDs: ["c1", "c2"]
        )

        let statePass1 = SummarizationRunState(
            runID: "run-seq",
            meetingID: "meeting-seq",
            status: .running,
            currentPassIndex: 1,
            totalPassCount: 3,
            lastValidCheckpoint: checkpointPass1,
            passRecords: [
                SummarizationPassRecord(passIndex: 1, chunkID: "c1", status: .completed),
                SummarizationPassRecord(passIndex: 2, chunkID: "c2", status: .pending),
                SummarizationPassRecord(passIndex: 3, chunkID: "c3", status: .pending),
            ]
        )
        try await store.save(statePass1, for: "meeting-seq")

        let statePass2 = SummarizationRunState(
            runID: "run-seq",
            meetingID: "meeting-seq",
            status: .running,
            currentPassIndex: 2,
            totalPassCount: 3,
            lastValidCheckpoint: checkpointPass2,
            passRecords: [
                SummarizationPassRecord(passIndex: 1, chunkID: "c1", status: .completed),
                SummarizationPassRecord(passIndex: 2, chunkID: "c2", status: .completed),
                SummarizationPassRecord(passIndex: 3, chunkID: "c3", status: .pending),
            ]
        )
        try await store.save(statePass2, for: "meeting-seq")

        let loaded = try await store.load(meetingID: "meeting-seq")
        #expect(loaded?.currentPassIndex == 2)
        #expect(loaded?.lastValidCheckpoint?.completedPassIndex == 2)
        #expect(loaded?.lastValidCheckpoint?.sourceChunkIDs == ["c1", "c2"])
    }

    @Test
    func saveEncodesDatesAsISO8601Strings() async throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-checkpoint-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        let store = DefaultSummarizationCheckpointStore(baseDirectoryURL: baseURL)
        let state = SummarizationRunState(
            runID: "run-iso",
            meetingID: "meeting-iso",
            status: .running,
            currentPassIndex: 1,
            totalPassCount: 2,
            tokenBudgetEstimate: SummarizationTokenBudgetEstimate(
                runID: "run-iso",
                modelID: "llama-test",
                contextWindowTokens: 8192,
                reservedOutputTokens: 1024,
                safetyMarginTokens: 256,
                promptOverheadTokens: 640,
                availableInputTokensPerPass: 6272,
                estimatedTotalInputTokens: 3000,
                estimatedPassCount: 2,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            lastValidCheckpoint: SummarizationSummaryCheckpoint(
                completedPassIndex: 1,
                summaryJSON: "{\"title\":\"Weekly\"}",
                sourceChunkIDs: ["c1"],
                updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
            )
        )

        try await store.save(state, for: "meeting-iso")

        let fileURL = baseURL.appendingPathComponent("meeting-iso.json")
        let rawJSON = try String(contentsOf: fileURL)

        #expect(rawJSON.contains("\"createdAt\":\""))
        #expect(rawJSON.contains("\"updatedAt\":\""))
        #expect(rawJSON.contains("T"))
    }

    @Test
    func loadDecodesLegacyReferenceDateTimestamps() async throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-checkpoint-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseURL) }

        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        let createdAt = 100.0
        let updatedAt = 200.0
        let legacyJSON = """
        {
          "runID": "run-legacy",
          "meetingID": "meeting-legacy",
          "status": "pausedForRetry",
          "currentPassIndex": 1,
          "totalPassCount": 2,
          "tokenBudgetEstimate": {
            "runID": "run-legacy",
            "modelID": "llama-legacy",
            "contextWindowTokens": 8192,
            "reservedOutputTokens": 1024,
            "safetyMarginTokens": 256,
            "promptOverheadTokens": 640,
            "availableInputTokensPerPass": 6272,
            "estimatedTotalInputTokens": 3000,
            "estimatedPassCount": 2,
            "createdAt": \(createdAt)
          },
          "lastValidCheckpoint": {
            "completedPassIndex": 1,
            "summaryJSON": "{\\"title\\":\\"Legacy\\"}",
            "sourceChunkIDs": ["c1"],
            "updatedAt": \(updatedAt)
          },
          "passRecords": []
        }
        """
        let fileURL = baseURL.appendingPathComponent("meeting-legacy.json")
        try legacyJSON.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = DefaultSummarizationCheckpointStore(baseDirectoryURL: baseURL)
        let loaded = try await store.load(meetingID: "meeting-legacy")

        #expect(loaded?.tokenBudgetEstimate?.createdAt == Date(timeIntervalSinceReferenceDate: createdAt))
        #expect(loaded?.lastValidCheckpoint?.updatedAt == Date(timeIntervalSinceReferenceDate: updatedAt))
    }
}
