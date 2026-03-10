import Foundation

public struct SummarizationPreflightConfiguration: Sendable, Equatable {
    public var contextWindowTokens: Int
    public var reservedOutputTokens: Int
    public var safetyMarginTokens: Int
    public var promptOverheadTokens: Int

    public init(
        contextWindowTokens: Int,
        reservedOutputTokens: Int,
        safetyMarginTokens: Int = 256,
        promptOverheadTokens: Int = 512
    ) {
        self.contextWindowTokens = contextWindowTokens
        self.reservedOutputTokens = reservedOutputTokens
        self.safetyMarginTokens = safetyMarginTokens
        self.promptOverheadTokens = promptOverheadTokens
    }

    public static let `default` = SummarizationPreflightConfiguration(
        contextWindowTokens: 8_192,
        reservedOutputTokens: 1_024
    )
}

public struct SummarizationPreflightEstimate: Sendable, Equatable {
    public let contextWindowTokens: Int
    public let reservedOutputTokens: Int
    public let safetyMarginTokens: Int
    public let promptOverheadTokens: Int
    public let availableInputTokensPerPass: Int
    public let estimatedTotalInputTokens: Int
    public let estimatedPassCount: Int

    public init(
        contextWindowTokens: Int,
        reservedOutputTokens: Int,
        safetyMarginTokens: Int,
        promptOverheadTokens: Int,
        availableInputTokensPerPass: Int,
        estimatedTotalInputTokens: Int,
        estimatedPassCount: Int
    ) {
        self.contextWindowTokens = contextWindowTokens
        self.reservedOutputTokens = reservedOutputTokens
        self.safetyMarginTokens = safetyMarginTokens
        self.promptOverheadTokens = promptOverheadTokens
        self.availableInputTokensPerPass = availableInputTokensPerPass
        self.estimatedTotalInputTokens = estimatedTotalInputTokens
        self.estimatedPassCount = estimatedPassCount
    }
}

public enum SummarizationPassPlanner {
    // Heuristic token estimate used for preflight only; runtime tokenization remains authoritative.
    private static let charsPerTokenEstimate = 4

    public static func estimate(
        transcript: String,
        contextWindowTokens: Int,
        reservedOutputTokens: Int,
        safetyMarginTokens: Int = 256,
        promptOverheadTokens: Int = 512,
        tokenEstimator: @Sendable (String) -> Int = estimateTokens(in:)
    ) -> SummarizationPreflightEstimate {
        let normalizedContext = max(512, contextWindowTokens)
        let normalizedOutputReserve = max(1, reservedOutputTokens)
        let normalizedMargin = max(0, safetyMarginTokens)
        let normalizedOverhead = max(0, promptOverheadTokens)
        let estimatedInputTokens = max(0, tokenEstimator(transcript))

        let available = max(
            128,
            normalizedContext - normalizedOutputReserve - normalizedMargin - normalizedOverhead
        )
        let estimatedPassCount = max(1, Int(ceil(Double(max(1, estimatedInputTokens)) / Double(available))))

        return SummarizationPreflightEstimate(
            contextWindowTokens: normalizedContext,
            reservedOutputTokens: normalizedOutputReserve,
            safetyMarginTokens: normalizedMargin,
            promptOverheadTokens: normalizedOverhead,
            availableInputTokensPerPass: available,
            estimatedTotalInputTokens: estimatedInputTokens,
            estimatedPassCount: estimatedPassCount
        )
    }

    public static func chunkTranscript(
        _ transcript: String,
        availableInputTokensPerPass: Int,
        tokenEstimator: @Sendable (String) -> Int = estimateTokens(in:)
    ) -> [String] {
        let budget = max(128, availableInputTokensPerPass)
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [""] }

        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var chunks: [String] = []
        var currentLines: [String] = []
        var currentTokenEstimate = 0

        func flushCurrent() {
            guard !currentLines.isEmpty else { return }
            chunks.append(currentLines.joined(separator: "\n"))
            currentLines.removeAll(keepingCapacity: true)
            currentTokenEstimate = 0
        }

        for line in lines {
            let lineTokens = max(1, tokenEstimator(line))

            // Single oversized line: emit it as its own chunk so planning always makes forward progress.
            if lineTokens > budget {
                flushCurrent()
                chunks.append(line)
                continue
            }

            if currentTokenEstimate + lineTokens > budget {
                flushCurrent()
            }

            currentLines.append(line)
            currentTokenEstimate += lineTokens
        }

        flushCurrent()
        return chunks.isEmpty ? [trimmed] : chunks
    }

    public static func estimateTokens(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return max(1, text.utf8.count / charsPerTokenEstimate)
    }
}
