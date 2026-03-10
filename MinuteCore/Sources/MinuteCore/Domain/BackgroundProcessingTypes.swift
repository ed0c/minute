import Foundation

public struct ActiveSummarizationStatus: Sendable, Equatable {
    public var preflightBudgetTokens: Int?
    public var estimatedPassCount: Int?
    public var currentPassIndex: Int?
    public var totalPassCount: Int?
    public var resumedFromPassIndex: Int?

    public init(
        preflightBudgetTokens: Int? = nil,
        estimatedPassCount: Int? = nil,
        currentPassIndex: Int? = nil,
        totalPassCount: Int? = nil,
        resumedFromPassIndex: Int? = nil
    ) {
        self.preflightBudgetTokens = preflightBudgetTokens
        self.estimatedPassCount = estimatedPassCount
        self.currentPassIndex = currentPassIndex
        self.totalPassCount = totalPassCount
        self.resumedFromPassIndex = resumedFromPassIndex
    }
}

public enum BackgroundProcessingOutcome: Sendable, Equatable {
    case completed(noteURL: URL, audioURL: URL?)
    case canceled
    case failed(message: String)
}

public struct BackgroundProcessingSnapshot: Sendable, Equatable {
    public var activeMeetingID: UUID?
    public var activeStage: PipelineStage?
    public var activeProgress: Double?
    public var activeSummarizationStatus: ActiveSummarizationStatus?

    public var pendingMeetingID: UUID?

    public var lastOutcome: BackgroundProcessingOutcome?

    public init(
        activeMeetingID: UUID? = nil,
        activeStage: PipelineStage? = nil,
        activeProgress: Double? = nil,
        activeSummarizationStatus: ActiveSummarizationStatus? = nil,
        pendingMeetingID: UUID? = nil,
        lastOutcome: BackgroundProcessingOutcome? = nil
    ) {
        self.activeMeetingID = activeMeetingID
        self.activeStage = activeStage
        self.activeProgress = activeProgress
        self.activeSummarizationStatus = activeSummarizationStatus
        self.pendingMeetingID = pendingMeetingID
        self.lastOutcome = lastOutcome
    }
}
