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
        let state = SummarizationRunState(
            runID: "run-1",
            meetingID: "meeting-1",
            status: .pausedForRetry,
            currentPassIndex: 2,
            totalPassCount: 5,
            lastValidCheckpoint: SummarizationSummaryCheckpoint(
                completedPassIndex: 2,
                summaryJSON: "{\"title\":\"Weekly\"}",
                sourceChunkIDs: ["c1", "c2"]
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
}
