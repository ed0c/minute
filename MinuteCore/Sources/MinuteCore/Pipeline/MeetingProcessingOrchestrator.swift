import Foundation
import os

public actor MeetingProcessingOrchestrator {
    public typealias ExecutePipeline = @Sendable (
        _ meetingID: UUID,
        _ context: PipelineContext,
        _ progress: (@Sendable (PipelineProgress) -> Void)?
    ) async throws -> PipelineResult

    private let logger = Logger(subsystem: "roblibob.Minute", category: "processing-orchestrator")

    private let busyGate: ProcessingBusyGate
    private let executePipeline: ExecutePipeline

    private var activeMeetingID: UUID?
    private var activeContext: PipelineContext?
    private var pending: (meetingID: UUID, context: PipelineContext)?

    private var lastRetryable: (meetingID: UUID, context: PipelineContext)?

    private var activeStage: PipelineStage?
    private var activeProgress: Double?
    private var activeSummarizationStatus: ActiveSummarizationStatus?
    private var lastOutcome: BackgroundProcessingOutcome?

    private var activeTask: Task<Void, Never>?
    private var snapshotObservers: [UUID: AsyncStream<BackgroundProcessingSnapshot>.Continuation] = [:]

    deinit {
        activeTask?.cancel()
        for continuation in snapshotObservers.values {
            continuation.finish()
        }
    }

    public init(
        busyGate: ProcessingBusyGate,
        executePipeline: @escaping ExecutePipeline
    ) {
        self.busyGate = busyGate
        self.executePipeline = executePipeline
    }

    public init(
        busyGate: ProcessingBusyGate,
        coordinator: MeetingPipelineCoordinator
    ) {
        self.busyGate = busyGate
        self.executePipeline = { meetingID, context, progress in
            _ = meetingID
            return try await coordinator.execute(context: context, progress: progress)
        }
    }

    public func snapshot() -> BackgroundProcessingSnapshot {
        currentSnapshot()
    }

    public func snapshots() -> AsyncStream<BackgroundProcessingSnapshot> {
        let observerID = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            Task { [weak self] in
                await self?.addSnapshotObserver(id: observerID, continuation: continuation)
            }
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeSnapshotObserver(id: observerID)
                }
            }
        }
    }

    public func cancelActiveProcessing(clearPending: Bool) {
        let shouldBroadcast = clearPending && pending != nil
        if clearPending {
            pending = nil
        }

        activeTask?.cancel()
        if shouldBroadcast {
            broadcastSnapshot()
        }
    }

    @discardableResult
    public func retryLastFailedOrCanceled() async -> Bool {
        guard let candidate = lastRetryable else {
            return false
        }

        if activeMeetingID == candidate.meetingID {
            return false
        }

        if pending?.meetingID == candidate.meetingID {
            return false
        }

        if activeMeetingID == nil {
            await startProcessing(meetingID: candidate.meetingID, context: candidate.context)
            return true
        }

        if pending == nil {
            pending = candidate
            broadcastSnapshot()
            return true
        }

        return false
    }

    @discardableResult
    public func enqueue(meetingID: UUID, context: PipelineContext) async -> Bool {
        if activeMeetingID == meetingID {
            return false
        }

        if pending?.meetingID == meetingID {
            return false
        }

        if activeMeetingID == nil {
            await startProcessing(meetingID: meetingID, context: context)
            return true
        }

        if pending == nil {
            pending = (meetingID: meetingID, context: context)
            broadcastSnapshot()
            return true
        }

        // v1 overflow policy: keep existing pending (FIFO). Additional meetings require manual action later.
        logger.info("Pending slot full; dropping auto-enqueue for meeting \(meetingID.uuidString, privacy: .public)")
        return false
    }

    private func startProcessing(meetingID: UUID, context: PipelineContext) async {
        activeTask?.cancel()

        activeMeetingID = meetingID
        activeContext = context
        activeStage = nil
        activeProgress = nil
        activeSummarizationStatus = nil
        lastOutcome = nil
        broadcastSnapshot()

        let token = await busyGate.beginBusyScope()
        let executePipeline = executePipeline

        activeTask = Task.detached(priority: .utility) {
            let outcome: BackgroundProcessingOutcome

            do {
                let result = try await executePipeline(meetingID, context) { [weak self] progress in
                    guard let self else { return }
                    Task { [weak self] in
                        guard let self else { return }
                        await self.updateProgress(progress)
                    }
                }

                outcome = .completed(noteURL: result.noteURL, audioURL: result.audioURL)
            } catch is CancellationError {
                outcome = .canceled
            } catch {
                let message = ErrorHandler.userMessage(for: error, fallback: "Processing failed.")
                outcome = .failed(message: message)
            }

            await self.finishActive(meetingID: meetingID, context: context, outcome: outcome)
            await token.end()
        }
    }

    private func updateProgress(_ progress: PipelineProgress) {
        let nextSummarizationStatus: ActiveSummarizationStatus?
        if progress.stage == .summarizing {
            nextSummarizationStatus = ActiveSummarizationStatus(
                preflightBudgetTokens: progress.preflightBudgetTokens,
                estimatedPassCount: progress.estimatedPassCount,
                currentPassIndex: progress.currentPassIndex,
                totalPassCount: progress.totalPassCount,
                resumedFromPassIndex: progress.resumedFromPassIndex
            )
        } else {
            nextSummarizationStatus = nil
        }

        let hasChanged =
            activeStage != progress.stage ||
            activeProgress != progress.fractionCompleted ||
            activeSummarizationStatus != nextSummarizationStatus
        activeStage = progress.stage
        activeProgress = progress.fractionCompleted
        activeSummarizationStatus = nextSummarizationStatus
        guard hasChanged else { return }
        broadcastSnapshot()
    }

    private func finishActive(meetingID: UUID, context: PipelineContext, outcome: BackgroundProcessingOutcome) async {
        lastOutcome = outcome

        switch outcome {
        case .canceled, .failed:
            lastRetryable = (meetingID: meetingID, context: context)
        case .completed:
            lastRetryable = nil
        }

        activeMeetingID = nil
        activeContext = nil
        activeStage = nil
        activeProgress = nil
        activeSummarizationStatus = nil
        activeTask = nil
        broadcastSnapshot()

        if let next = pending {
            pending = nil
            await startProcessing(meetingID: next.meetingID, context: next.context)
        }
    }

    private func addSnapshotObserver(
        id: UUID,
        continuation: AsyncStream<BackgroundProcessingSnapshot>.Continuation
    ) {
        snapshotObservers[id] = continuation
        continuation.yield(currentSnapshot())
    }

    private func removeSnapshotObserver(id: UUID) {
        snapshotObservers.removeValue(forKey: id)
    }

    private func currentSnapshot() -> BackgroundProcessingSnapshot {
        BackgroundProcessingSnapshot(
            activeMeetingID: activeMeetingID,
            activeStage: activeStage,
            activeProgress: activeProgress,
            activeSummarizationStatus: activeSummarizationStatus,
            pendingMeetingID: pending?.meetingID,
            lastOutcome: lastOutcome
        )
    }

    private func broadcastSnapshot() {
        let snapshot = currentSnapshot()
        for continuation in snapshotObservers.values {
            continuation.yield(snapshot)
        }
    }
}
