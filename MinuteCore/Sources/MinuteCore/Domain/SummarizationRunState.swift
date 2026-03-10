import Foundation

public struct SummarizationTokenBudgetEstimate: Sendable, Codable, Equatable {
    public var runID: String
    public var modelID: String
    public var contextWindowTokens: Int
    public var reservedOutputTokens: Int
    public var safetyMarginTokens: Int
    public var promptOverheadTokens: Int
    public var availableInputTokensPerPass: Int
    public var estimatedTotalInputTokens: Int
    public var estimatedPassCount: Int
    public var createdAt: Date

    public init(
        runID: String,
        modelID: String,
        contextWindowTokens: Int,
        reservedOutputTokens: Int,
        safetyMarginTokens: Int,
        promptOverheadTokens: Int,
        availableInputTokensPerPass: Int,
        estimatedTotalInputTokens: Int,
        estimatedPassCount: Int,
        createdAt: Date = Date()
    ) {
        self.runID = runID
        self.modelID = modelID
        self.contextWindowTokens = contextWindowTokens
        self.reservedOutputTokens = reservedOutputTokens
        self.safetyMarginTokens = safetyMarginTokens
        self.promptOverheadTokens = promptOverheadTokens
        self.availableInputTokensPerPass = availableInputTokensPerPass
        self.estimatedTotalInputTokens = estimatedTotalInputTokens
        self.estimatedPassCount = estimatedPassCount
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case runID = "runId"
        case modelID = "modelId"
        case contextWindowTokens
        case reservedOutputTokens
        case safetyMarginTokens
        case promptOverheadTokens
        case availableInputTokensPerPass
        case estimatedTotalInputTokens
        case estimatedPassCount
        case createdAt
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case runID
        case modelID
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)

        self.runID = try container.decodeIfPresent(String.self, forKey: .runID)
            ?? legacyContainer.decode(String.self, forKey: .runID)
        self.modelID = try container.decodeIfPresent(String.self, forKey: .modelID)
            ?? legacyContainer.decode(String.self, forKey: .modelID)
        self.contextWindowTokens = try container.decode(Int.self, forKey: .contextWindowTokens)
        self.reservedOutputTokens = try container.decode(Int.self, forKey: .reservedOutputTokens)
        self.safetyMarginTokens = try container.decode(Int.self, forKey: .safetyMarginTokens)
        self.promptOverheadTokens = try container.decode(Int.self, forKey: .promptOverheadTokens)
        self.availableInputTokensPerPass = try container.decode(Int.self, forKey: .availableInputTokensPerPass)
        self.estimatedTotalInputTokens = try container.decode(Int.self, forKey: .estimatedTotalInputTokens)
        self.estimatedPassCount = try container.decode(Int.self, forKey: .estimatedPassCount)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(runID, forKey: .runID)
        try container.encode(modelID, forKey: .modelID)
        try container.encode(contextWindowTokens, forKey: .contextWindowTokens)
        try container.encode(reservedOutputTokens, forKey: .reservedOutputTokens)
        try container.encode(safetyMarginTokens, forKey: .safetyMarginTokens)
        try container.encode(promptOverheadTokens, forKey: .promptOverheadTokens)
        try container.encode(availableInputTokensPerPass, forKey: .availableInputTokensPerPass)
        try container.encode(estimatedTotalInputTokens, forKey: .estimatedTotalInputTokens)
        try container.encode(estimatedPassCount, forKey: .estimatedPassCount)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

public struct SummarizationTranscriptChunkPlan: Sendable, Codable, Equatable {
    public var chunkID: String
    public var passIndex: Int
    public var tokenStart: Int
    public var tokenEnd: Int
    public var tokenCount: Int

    public init(chunkID: String, passIndex: Int, tokenStart: Int, tokenEnd: Int, tokenCount: Int) {
        self.chunkID = chunkID
        self.passIndex = passIndex
        self.tokenStart = tokenStart
        self.tokenEnd = tokenEnd
        self.tokenCount = tokenCount
    }
}

public struct SummarizationPassPlan: Sendable, Codable, Equatable {
    public var runID: String
    public var chunks: [SummarizationTranscriptChunkPlan]
    public var createdAt: Date

    public init(runID: String, chunks: [SummarizationTranscriptChunkPlan], createdAt: Date = Date()) {
        self.runID = runID
        self.chunks = chunks
        self.createdAt = createdAt
    }
}

public struct SummarizationOutputPaths: Sendable, Codable, Equatable {
    public var noteRelativePath: String
    public var audioRelativePath: String?
    public var transcriptRelativePath: String?

    public init(
        noteRelativePath: String,
        audioRelativePath: String? = nil,
        transcriptRelativePath: String? = nil
    ) {
        self.noteRelativePath = noteRelativePath
        self.audioRelativePath = audioRelativePath
        self.transcriptRelativePath = transcriptRelativePath
    }
}

public struct SummarizationSummaryCheckpoint: Sendable, Codable, Equatable {
    public var completedPassIndex: Int
    public var summaryJSON: String
    public var mergeStateJSON: String?
    public var sourceChunkIDs: [String]
    public var updatedAt: Date

    public init(
        completedPassIndex: Int,
        summaryJSON: String,
        mergeStateJSON: String? = nil,
        sourceChunkIDs: [String],
        updatedAt: Date = Date()
    ) {
        self.completedPassIndex = completedPassIndex
        self.summaryJSON = summaryJSON
        self.mergeStateJSON = mergeStateJSON
        self.sourceChunkIDs = sourceChunkIDs
        self.updatedAt = updatedAt
    }
}

public enum SummarizationPassStatus: String, Sendable, Codable, Equatable {
    case pending
    case running
    case completed
    case failed
    case cancelled
    case skipped
}

public struct SummarizationPassRecord: Sendable, Codable, Equatable {
    public var passIndex: Int
    public var chunkID: String
    public var status: SummarizationPassStatus
    public var startedAt: Date?
    public var finishedAt: Date?
    public var errorCode: String?
    public var errorMessage: String?

    public init(
        passIndex: Int,
        chunkID: String,
        status: SummarizationPassStatus,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) {
        self.passIndex = passIndex
        self.chunkID = chunkID
        self.status = status
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

public enum SummarizationRunStatus: String, Sendable, Codable, Equatable {
    case initialized = "initialized"
    case planning = "planning"
    case running = "running"
    case pausedForRetry = "paused_for_retry"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.pausedForRetry.rawValue, "pausedForRetry":
            self = .pausedForRetry
        case Self.initialized.rawValue:
            self = .initialized
        case Self.planning.rawValue:
            self = .planning
        case Self.running.rawValue:
            self = .running
        case Self.completed.rawValue:
            self = .completed
        case Self.failed.rawValue:
            self = .failed
        case Self.cancelled.rawValue:
            self = .cancelled
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported summarization run status: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct SummarizationRunState: Sendable, Codable, Equatable {
    public var runID: String
    public var meetingID: String
    public var status: SummarizationRunStatus
    public var currentPassIndex: Int
    public var totalPassCount: Int
    public var tokenBudgetEstimate: SummarizationTokenBudgetEstimate?
    public var passPlan: SummarizationPassPlan?
    public var outputPaths: SummarizationOutputPaths?
    public var lastValidCheckpoint: SummarizationSummaryCheckpoint?
    public var passRecords: [SummarizationPassRecord]

    public init(
        runID: String,
        meetingID: String,
        status: SummarizationRunStatus,
        currentPassIndex: Int,
        totalPassCount: Int,
        tokenBudgetEstimate: SummarizationTokenBudgetEstimate? = nil,
        passPlan: SummarizationPassPlan? = nil,
        outputPaths: SummarizationOutputPaths? = nil,
        lastValidCheckpoint: SummarizationSummaryCheckpoint? = nil,
        passRecords: [SummarizationPassRecord] = []
    ) {
        self.runID = runID
        self.meetingID = meetingID
        self.status = status
        self.currentPassIndex = currentPassIndex
        self.totalPassCount = totalPassCount
        self.tokenBudgetEstimate = tokenBudgetEstimate
        self.passPlan = passPlan
        self.outputPaths = outputPaths
        self.lastValidCheckpoint = lastValidCheckpoint
        self.passRecords = passRecords
    }
}
