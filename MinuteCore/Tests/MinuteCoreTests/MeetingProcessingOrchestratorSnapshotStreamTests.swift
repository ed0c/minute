import Foundation
import Testing
@testable import MinuteCore

struct MeetingProcessingOrchestratorSnapshotStreamTests {
    @Test
    func snapshots_emitsInitialAndStateTransitions() async throws {
        let gate = ProcessingBusyGate()
        let executor = SnapshotStreamBlockingExecutor()
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        let recorder = SnapshotStreamRecorder()
        let stream = await orchestrator.snapshots()
        let streamTask = Task {
            for await snapshot in stream {
                await recorder.append(snapshot)
            }
        }
        defer { streamTask.cancel() }

        try await recorder.waitUntilContains(activeMeetingID: nil, pendingMeetingID: nil)

        let meetingA = UUID()
        let meetingB = UUID()
        let contextA = try makeSnapshotPipelineContext()
        let contextB = try makeSnapshotPipelineContext()

        _ = await orchestrator.enqueue(meetingID: meetingA, context: contextA)
        try await executor.waitUntilBlocked(meetingID: meetingA)
        try await recorder.waitUntilContains(activeMeetingID: meetingA, pendingMeetingID: nil)

        _ = await orchestrator.enqueue(meetingID: meetingB, context: contextB)
        try await recorder.waitUntilContains(activeMeetingID: meetingA, pendingMeetingID: meetingB)

        await executor.finish(meetingID: meetingA)
        try await executor.waitUntilBlocked(meetingID: meetingB)
        try await recorder.waitUntilContains(activeMeetingID: meetingB, pendingMeetingID: nil)

        await executor.finish(meetingID: meetingB)
        await gate.waitUntilIdle()
    }
}

private actor SnapshotStreamRecorder {
    enum WaitError: Error {
        case timeout
    }

    private var snapshots: [BackgroundProcessingSnapshot] = []

    func append(_ snapshot: BackgroundProcessingSnapshot) {
        snapshots.append(snapshot)
    }

    func waitUntilContains(
        activeMeetingID: UUID?,
        pendingMeetingID: UUID?,
        timeoutSeconds: TimeInterval = 1.0
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !snapshots.contains(where: { snapshot in
            snapshot.activeMeetingID == activeMeetingID &&
                snapshot.pendingMeetingID == pendingMeetingID
        }) {
            if Date() >= deadline {
                throw WaitError.timeout
            }
            await Task.yield()
        }
    }
}

private actor SnapshotStreamBlockingExecutor {
    enum WaitError: Error {
        case timeout
    }

    private var continuations: [UUID: CheckedContinuation<Void, Never>] = [:]

    func execute(
        meetingID: UUID,
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)?
    ) async throws -> PipelineResult {
        _ = context
        _ = progress

        await withCheckedContinuation { continuation in
            continuations[meetingID] = continuation
        }
        return PipelineResult(noteURL: URL(fileURLWithPath: "/tmp/note.md"), audioURL: nil)
    }

    func finish(meetingID: UUID) {
        continuations.removeValue(forKey: meetingID)?.resume()
    }

    func waitUntilBlocked(meetingID: UUID, timeoutSeconds: TimeInterval = 1.0) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while continuations[meetingID] == nil {
            if Date() >= deadline {
                throw WaitError.timeout
            }
            await Task.yield()
        }
    }
}

private func makeSnapshotPipelineContext() throws -> PipelineContext {
    let audioTempURL = try makeSnapshotTemporaryAudioFile()
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let stoppedAt = startedAt.addingTimeInterval(60)
    let workingDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-snapshot-work-\(UUID().uuidString)", isDirectory: true)

    return PipelineContext(
        vaultFolders: MeetingFileContract.VaultFolders(),
        audioTempURL: audioTempURL,
        audioDurationSeconds: 60,
        startedAt: startedAt,
        stoppedAt: stoppedAt,
        workingDirectoryURL: workingDirectoryURL,
        saveAudio: false,
        saveTranscript: false,
        screenContextEvents: []
    )
}

private func makeSnapshotTemporaryAudioFile() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-snapshot-audio-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("audio.wav")
    try Data([0x00, 0x01]).write(to: fileURL, options: [.atomic])
    return fileURL
}
