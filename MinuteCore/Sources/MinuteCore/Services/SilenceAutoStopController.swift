import Foundation

public actor SilenceAutoStopController: SilenceAutoStopControlling {
    private let policy: SilenceDetectionPolicy
    private let onEvent: (@Sendable (SilenceAutoStopEvent) -> Void)?

    private var sessionID: UUID?
    private var phase: SilenceDetectionPhase = .inactive
    private var silenceAccumulatedSeconds: TimeInterval = 0
    private var nonSilentBurstSeconds: TimeInterval = 0
    private var warningStartedAt: Date?
    private var warningDeadlineAt: Date?
    private var pendingAutoStop = false
    private var lastSampleAt: Date?
    private var countdownTask: Task<Void, Never>?

    public init(
        policy: SilenceDetectionPolicy = .default,
        onEvent: (@Sendable (SilenceAutoStopEvent) -> Void)? = nil
    ) {
        self.policy = policy
        self.onEvent = onEvent
    }

    deinit {
        countdownTask?.cancel()
    }

    public func start(sessionID: UUID, startedAt: Date) async {
        _ = startedAt
        countdownTask?.cancel()
        countdownTask = nil

        self.sessionID = sessionID
        phase = .monitoring
        silenceAccumulatedSeconds = 0
        nonSilentBurstSeconds = 0
        warningStartedAt = nil
        warningDeadlineAt = nil
        pendingAutoStop = false
        lastSampleAt = nil
        emitStatusChanged()
    }

    public func stop() async {
        countdownTask?.cancel()
        countdownTask = nil

        phase = .inactive
        silenceAccumulatedSeconds = 0
        nonSilentBurstSeconds = 0
        warningStartedAt = nil
        warningDeadlineAt = nil
        pendingAutoStop = false
        lastSampleAt = nil
        emitStatusChanged()
    }

    public func ingest(level: Float, at: Date = Date()) async {
        guard phase != .inactive else { return }

        let delta: TimeInterval = {
            guard let lastSampleAt else { return 0 }
            return max(0, at.timeIntervalSince(lastSampleAt))
        }()
        lastSampleAt = at

        let isSilent = level < policy.rmsSilenceThreshold

        if phase == .warningActive {
            if !isSilent {
                await cancelWarningBySpeech()
            }
            return
        }

        if isSilent {
            nonSilentBurstSeconds = 0
            silenceAccumulatedSeconds += delta
        } else {
            nonSilentBurstSeconds += delta
            if nonSilentBurstSeconds > policy.transientToleranceSeconds {
                silenceAccumulatedSeconds = 0
                nonSilentBurstSeconds = 0
            }
        }

        if silenceAccumulatedSeconds >= policy.silenceDurationSeconds {
            await beginWarning(at: at)
            return
        }

        emitStatusChanged()
    }

    public func keepRecording() async {
        guard phase == .warningActive else { return }

        countdownTask?.cancel()
        countdownTask = nil

        phase = .canceledByUser
        pendingAutoStop = false
        warningStartedAt = nil
        warningDeadlineAt = nil
        silenceAccumulatedSeconds = 0
        nonSilentBurstSeconds = 0

        onEvent?(.warningCanceledByUser)
        phase = .monitoring
        emitStatusChanged()
    }

    public func status() async -> SilenceStatusSnapshot {
        makeSnapshot()
    }

    private func beginWarning(at now: Date) async {
        guard phase != .warningActive else { return }
        guard let sessionID else { return }

        phase = .warningActive
        pendingAutoStop = true
        warningStartedAt = now
        warningDeadlineAt = now.addingTimeInterval(policy.warningCountdownSeconds)

        let alert = RecordingAlert(
            type: .silenceStopWarning,
            sessionID: sessionID,
            message: "Recording will stop in \(Int(policy.warningCountdownSeconds)) seconds unless you keep recording.",
            issuedAt: now,
            expiresAt: warningDeadlineAt,
            actions: [.keepRecording]
        )
        onEvent?(.warningStarted(alert))
        emitStatusChanged()

        countdownTask?.cancel()
        let nanoseconds = UInt64(max(policy.warningCountdownSeconds, 0) * 1_000_000_000)
        countdownTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: nanoseconds)
            await self.triggerAutoStopIfNeeded()
        }
    }

    private func cancelWarningBySpeech() async {
        guard phase == .warningActive else { return }

        countdownTask?.cancel()
        countdownTask = nil

        phase = .canceledBySpeech
        pendingAutoStop = false
        warningStartedAt = nil
        warningDeadlineAt = nil
        silenceAccumulatedSeconds = 0
        nonSilentBurstSeconds = 0

        onEvent?(.warningCanceledBySpeech)

        phase = .monitoring
        emitStatusChanged()
    }

    private func triggerAutoStopIfNeeded() {
        guard phase == .warningActive, pendingAutoStop else { return }

        phase = .autoStopExecuted
        pendingAutoStop = false
        warningStartedAt = nil
        warningDeadlineAt = nil
        onEvent?(.autoStopTriggered)
        emitStatusChanged()
    }

    private func makeSnapshot() -> SilenceStatusSnapshot {
        SilenceStatusSnapshot(
            sessionID: sessionID,
            phase: phase,
            silenceAccumulatedSeconds: silenceAccumulatedSeconds,
            warningStartedAt: warningStartedAt,
            warningDeadlineAt: warningDeadlineAt,
            pendingAutoStop: pendingAutoStop
        )
    }

    private func emitStatusChanged() {
        onEvent?(.statusChanged(makeSnapshot()))
    }
}
