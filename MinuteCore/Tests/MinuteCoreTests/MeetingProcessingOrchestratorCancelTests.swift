import Foundation
import Testing
@testable import MinuteCore

struct MeetingProcessingOrchestratorCancelTests {
    @Test
    func cancelActiveProcessing_setsOutcomeCanceled_andGateBecomesIdle() async throws {
        let recorder = ExecutionRecorder()
        let executor = CancellablePipelineExecutor(recorder: recorder)
        let gate = ProcessingBusyGate()
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        let a = UUID()
        let contextA = try makePipelineContext()

        _ = await orchestrator.enqueue(meetingID: a, context: contextA)
        try await recorder.waitUntilStarted(meetingID: a)

        #expect(await gate.isBusy == true)

        await orchestrator.cancelActiveProcessing(clearPending: false)
        await gate.waitUntilIdle()

        let snapshot = await orchestrator.snapshot()
        #expect(snapshot.activeMeetingID == nil)
        #expect(snapshot.pendingMeetingID == nil)
        #expect(snapshot.lastOutcome == .canceled)
        #expect(await gate.isBusy == false)
    }

    @Test
    func cancelActiveProcessing_default_keepsPending_andAutoStartsPendingAfterCancel() async throws {
        let recorder = ExecutionRecorder()
        let executor = CancellablePipelineExecutor(recorder: recorder)
        let gate = ProcessingBusyGate()
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        let a = UUID()
        let b = UUID()
        let contextA = try makePipelineContext()
        let contextB = try makePipelineContext()

        _ = await orchestrator.enqueue(meetingID: a, context: contextA)
        try await recorder.waitUntilStarted(meetingID: a)

        _ = await orchestrator.enqueue(meetingID: b, context: contextB)
        #expect(await orchestrator.snapshot().pendingMeetingID == b)

        await orchestrator.cancelActiveProcessing(clearPending: false)

        // Pending meeting should start after the canceled run finishes.
        try await recorder.waitUntilStarted(meetingID: b)

        let started = await recorder.startedSnapshot()
        #expect(started == [a, b])

        // Cancel the second run as well to end the test deterministically.
        await orchestrator.cancelActiveProcessing(clearPending: false)
        await gate.waitUntilIdle()

        let snapshot = await orchestrator.snapshot()
        #expect(snapshot.activeMeetingID == nil)
        #expect(snapshot.pendingMeetingID == nil)
        #expect(snapshot.lastOutcome == .canceled)
    }

    @Test
    func cancelActiveProcessing_whenClearPending_true_clearsPending_andDoesNotAutoStartPending() async throws {
        let recorder = ExecutionRecorder()
        let executor = CancellablePipelineExecutor(recorder: recorder)
        let gate = ProcessingBusyGate()
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        let a = UUID()
        let b = UUID()
        let contextA = try makePipelineContext()
        let contextB = try makePipelineContext()

        _ = await orchestrator.enqueue(meetingID: a, context: contextA)
        try await recorder.waitUntilStarted(meetingID: a)

        _ = await orchestrator.enqueue(meetingID: b, context: contextB)
        #expect(await orchestrator.snapshot().pendingMeetingID == b)

        await orchestrator.cancelActiveProcessing(clearPending: true)
        await gate.waitUntilIdle()

        let snapshot = await orchestrator.snapshot()
        #expect(snapshot.activeMeetingID == nil)
        #expect(snapshot.pendingMeetingID == nil)
        #expect(snapshot.lastOutcome == .canceled)

        let started = await recorder.startedSnapshot()
        #expect(started == [a])
    }

    @Test
    func diarizationService_whenCancelledDuringModelPrepare_throwsCancellation_andDoesNotInvokeDiarize() async throws {
        let recorder = CancellationRecorder()
        let offlineManager = CancellingOfflineManager(recorder: recorder)
        let service = FluidAudioOfflineDiarizationService(
            configuration: FluidAudioOfflineDiarizationConfiguration(),
            offlineManager: offlineManager
        )

        let wavURL = try makeTemporaryAudioFile()

        let task = Task {
            try await service.diarize(wavURL: wavURL, embeddingExportURL: nil)
        }

        try await recorder.waitUntilPrepareStarted()
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            // expected
        }

        #expect(await recorder.didStartDiarize == false)
    }

    @Test
    func loudnessNormalizer_whenCancelledDuringPass1_throwsCancellation() async throws {
        let recorder = CancellationRecorder()
        let runner = CancellingProcessRunner(recorder: recorder)
        let normalizer = AudioLoudnessNormalizer(
            processRunner: runner,
            environment: ["MINUTE_FFMPEG_BIN": "/usr/bin/true"]
        )

        let workingDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-cancel-loudnorm-\(UUID().uuidString)", isDirectory: true)
        let inputURL = try makeTemporaryAudioFile()

        let task = Task {
            try await normalizer.normalizeForAnalysis(inputURL: inputURL, workingDirectoryURL: workingDirectoryURL)
        }

        try await recorder.waitUntilPass1Started()
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            // expected
        }
    }

    @Test
    func cancelActiveProcessing_thenPendingCompletion_updatesLastOutcomeToCompleted() async throws {
        let gate = ProcessingBusyGate()
        let primaryMeetingID = UUID()
        let pendingMeetingID = UUID()
        let contextPrimary = try makePipelineContext()
        let contextPending = try makePipelineContext()
        let completedNoteURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-completed-\(UUID().uuidString).md")

        let executor = MixedOutcomePipelineExecutor(
            cancellableMeetingID: primaryMeetingID,
            completedNoteURL: completedNoteURL
        )
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        _ = await orchestrator.enqueue(meetingID: primaryMeetingID, context: contextPrimary)
        try await executor.waitUntilStarted(meetingID: primaryMeetingID)

        _ = await orchestrator.enqueue(meetingID: pendingMeetingID, context: contextPending)
        await orchestrator.cancelActiveProcessing(clearPending: false)

        await gate.waitUntilIdle()

        let started = await executor.startedSnapshot()
        #expect(started == [primaryMeetingID, pendingMeetingID])

        let snapshot = await orchestrator.snapshot()
        switch snapshot.lastOutcome {
        case .completed(let noteURL, _):
            #expect(noteURL == completedNoteURL)
        default:
            Issue.record("Expected completed outcome after pending run finishes")
        }
    }

    @Test
    func retryLastFailedOrCanceled_afterCanceledRun_completesAndReplacesCanceledOutcome() async throws {
        let gate = ProcessingBusyGate()
        let meetingID = UUID()
        let context = try makePipelineContext()
        let completedNoteURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-retry-completed-\(UUID().uuidString).md")

        let executor = FirstAttemptCancelsThenCompletesExecutor(
            meetingID: meetingID,
            completedNoteURL: completedNoteURL
        )
        let orchestrator = MeetingProcessingOrchestrator(busyGate: gate, executePipeline: executor.execute)

        _ = await orchestrator.enqueue(meetingID: meetingID, context: context)
        try await executor.waitUntilStartedAttempt(meetingID: meetingID, attempt: 1)
        await orchestrator.cancelActiveProcessing(clearPending: false)
        await gate.waitUntilIdle()

        let canceledSnapshot = await orchestrator.snapshot()
        #expect(canceledSnapshot.lastOutcome == .canceled)

        let retryAccepted = await orchestrator.retryLastFailedOrCanceled()
        #expect(retryAccepted)
        try await executor.waitUntilStartedAttempt(meetingID: meetingID, attempt: 2)
        await gate.waitUntilIdle()

        let snapshot = await orchestrator.snapshot()
        switch snapshot.lastOutcome {
        case .completed(let noteURL, _):
            #expect(noteURL == completedNoteURL)
        default:
            Issue.record("Expected completed outcome after retry")
        }
    }
}

private actor CancellationRecorder {
    enum WaitError: Error {
        case timeout
    }

    private(set) var prepareStarted = false
    private(set) var diarizeStarted = false

    private(set) var pass1Started = false

    func markPrepareStarted() {
        prepareStarted = true
    }

    func markDiarizeStarted() {
        diarizeStarted = true
    }

    func markPass1Started() {
        pass1Started = true
    }

    func waitUntilPrepareStarted() async throws {
        try await waitUntil { prepareStarted }
    }

    func waitUntilPass1Started() async throws {
        try await waitUntil { pass1Started }
    }

    var didStartDiarize: Bool {
        diarizeStarted
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(1.0)
        while !predicate() {
            if Date() > deadline {
                throw WaitError.timeout
            }
            await Task.yield()
        }
    }
}

private struct CancellingOfflineManager: OfflineDiarizerManaging {
    let recorder: CancellationRecorder

    func prepareModels() async throws {
        await recorder.markPrepareStarted()
        while true {
            try Task.checkCancellation()
            await Task.yield()
        }
    }

    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment] {
        _ = wavURL
        _ = embeddingExportURL
        await recorder.markDiarizeStarted()
        return []
    }
}

private struct CancellingProcessRunner: ProcessRunning {
    let recorder: CancellationRecorder

    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String : String]?,
        workingDirectoryURL: URL?,
        maximumOutputBytes: Int
    ) async throws -> ProcessResult {
        _ = executableURL
        _ = arguments
        _ = environment
        _ = workingDirectoryURL
        _ = maximumOutputBytes

        await recorder.markPass1Started()

        while true {
            try Task.checkCancellation()
            await Task.yield()
        }

        throw CancellationError()
    }
}

private actor ExecutionRecorder {
    enum WaitError: Error {
        case timeout
    }

    private(set) var started: [UUID] = []

    func recordStart(_ meetingID: UUID) {
        started.append(meetingID)
    }

    func startedSnapshot() -> [UUID] {
        started
    }

    func waitUntilStarted(meetingID: UUID) async throws {
        let deadline = Date().addingTimeInterval(1.0)

        while !started.contains(meetingID) {
            if Date() > deadline {
                throw WaitError.timeout
            }
            await Task.yield()
        }
    }
}

private actor CancellablePipelineExecutor {
    private let recorder: ExecutionRecorder

    init(recorder: ExecutionRecorder) {
        self.recorder = recorder
    }

    func execute(
        meetingID: UUID,
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)?
    ) async throws -> PipelineResult {
        _ = context
        _ = progress

        await recorder.recordStart(meetingID)

        while true {
            try Task.checkCancellation()
            await Task.yield()
        }

        throw CancellationError()
    }
}

private actor MixedOutcomePipelineExecutor {
    enum WaitError: Error {
        case timeout
    }

    private let cancellableMeetingID: UUID
    private let completedNoteURL: URL
    private var started: [UUID] = []

    init(cancellableMeetingID: UUID, completedNoteURL: URL) {
        self.cancellableMeetingID = cancellableMeetingID
        self.completedNoteURL = completedNoteURL
    }

    func execute(
        meetingID: UUID,
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)?
    ) async throws -> PipelineResult {
        _ = context
        _ = progress

        started.append(meetingID)

        if meetingID == cancellableMeetingID {
            while true {
                try Task.checkCancellation()
                await Task.yield()
            }
        }

        return PipelineResult(noteURL: completedNoteURL, audioURL: nil)
    }

    func startedSnapshot() -> [UUID] {
        started
    }

    func waitUntilStarted(meetingID: UUID) async throws {
        let deadline = Date().addingTimeInterval(1.0)
        while !started.contains(meetingID) {
            if Date() > deadline {
                throw WaitError.timeout
            }
            await Task.yield()
        }
    }
}

private actor FirstAttemptCancelsThenCompletesExecutor {
    enum WaitError: Error {
        case timeout
    }

    private let meetingID: UUID
    private let completedNoteURL: URL
    private var startAttempts: [UUID: Int] = [:]

    init(meetingID: UUID, completedNoteURL: URL) {
        self.meetingID = meetingID
        self.completedNoteURL = completedNoteURL
    }

    func execute(
        meetingID: UUID,
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)?
    ) async throws -> PipelineResult {
        _ = context
        _ = progress

        let attempt = (startAttempts[meetingID] ?? 0) + 1
        startAttempts[meetingID] = attempt

        if meetingID == self.meetingID, attempt == 1 {
            while true {
                try Task.checkCancellation()
                await Task.yield()
            }
        }

        return PipelineResult(noteURL: completedNoteURL, audioURL: nil)
    }

    func waitUntilStartedAttempt(meetingID: UUID, attempt: Int) async throws {
        let deadline = Date().addingTimeInterval(1.0)
        while (startAttempts[meetingID] ?? 0) < attempt {
            if Date() > deadline {
                throw WaitError.timeout
            }
            await Task.yield()
        }
    }
}

private func makePipelineContext() throws -> PipelineContext {
    let audioTempURL = try makeTemporaryAudioFile()
    let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let stoppedAt = startedAt.addingTimeInterval(60)
    let workingDirectoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-work-\(UUID().uuidString)", isDirectory: true)

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

private func makeTemporaryAudioFile() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("minute-audio-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fileURL = directory.appendingPathComponent("audio.wav")
    try Data([0x00, 0x01]).write(to: fileURL, options: [.atomic])
    return fileURL
}
