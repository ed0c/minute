import Foundation

public struct SilenceDetectionPolicy: Sendable, Equatable, Codable {
    public var silenceDurationSeconds: TimeInterval
    public var warningCountdownSeconds: TimeInterval
    public var rmsSilenceThreshold: Float
    public var transientToleranceSeconds: TimeInterval

    public init(
        silenceDurationSeconds: TimeInterval = 120,
        warningCountdownSeconds: TimeInterval = 30,
        rmsSilenceThreshold: Float = 0.03,
        transientToleranceSeconds: TimeInterval = 0.75
    ) {
        self.silenceDurationSeconds = silenceDurationSeconds
        self.warningCountdownSeconds = warningCountdownSeconds
        self.rmsSilenceThreshold = rmsSilenceThreshold
        self.transientToleranceSeconds = transientToleranceSeconds
    }

    public static let `default` = SilenceDetectionPolicy()

    public var isValid: Bool {
        silenceDurationSeconds > 0 &&
        warningCountdownSeconds > 0 &&
        rmsSilenceThreshold >= 0 &&
        rmsSilenceThreshold <= 1 &&
        transientToleranceSeconds >= 0
    }
}

public enum SilenceDetectionPhase: String, Sendable, Equatable, Codable {
    case monitoring
    case warningActive = "warning_active"
    case autoStopExecuted = "auto_stop_executed"
    case canceledByUser = "canceled_by_user"
    case canceledBySpeech = "canceled_by_speech"
    case inactive
}

public struct SilenceStatusSnapshot: Sendable, Equatable, Codable {
    public var sessionID: UUID?
    public var phase: SilenceDetectionPhase
    public var silenceAccumulatedSeconds: TimeInterval
    public var warningStartedAt: Date?
    public var warningDeadlineAt: Date?
    public var pendingAutoStop: Bool

    public init(
        sessionID: UUID? = nil,
        phase: SilenceDetectionPhase = .inactive,
        silenceAccumulatedSeconds: TimeInterval = 0,
        warningStartedAt: Date? = nil,
        warningDeadlineAt: Date? = nil,
        pendingAutoStop: Bool = false
    ) {
        self.sessionID = sessionID
        self.phase = phase
        self.silenceAccumulatedSeconds = silenceAccumulatedSeconds
        self.warningStartedAt = warningStartedAt
        self.warningDeadlineAt = warningDeadlineAt
        self.pendingAutoStop = pendingAutoStop
    }

    public var warningActive: Bool {
        phase == .warningActive && pendingAutoStop
    }

    public var warningRemainingSeconds: Int? {
        guard let warningDeadlineAt, warningActive else { return nil }
        return max(Int(ceil(warningDeadlineAt.timeIntervalSinceNow)), 0)
    }
}
