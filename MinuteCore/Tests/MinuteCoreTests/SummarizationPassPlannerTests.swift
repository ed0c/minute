import Foundation
import Testing
@testable import MinuteCore

struct SummarizationPassPlannerTests {
    @Test
    func estimateReturnsPositiveBudgetAndPassCount() {
        let transcript = String(repeating: "line of transcript content ", count: 600)

        let estimate = SummarizationPassPlanner.estimate(
            transcript: transcript,
            contextWindowTokens: 4096,
            reservedOutputTokens: 1024,
            safetyMarginTokens: 256,
            promptOverheadTokens: 512
        )

        #expect(estimate.availableInputTokensPerPass > 0)
        #expect(estimate.estimatedPassCount >= 1)
        #expect(estimate.estimatedTotalInputTokens > 0)
    }

    @Test
    func chunkTranscriptSplitsIntoMultipleChunksWhenOverBudget() {
        let transcript = (0..<200)
            .map { "[\($0)] This is a long transcript line that should be chunked deterministically." }
            .joined(separator: "\n")

        let chunks = SummarizationPassPlanner.chunkTranscript(transcript, availableInputTokensPerPass: 128)

        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { !$0.isEmpty })
    }

    @Test
    func chunkTranscriptIsDeterministicForSameInput() {
        let transcript = (0..<120)
            .map { "line-\($0) value value value value value" }
            .joined(separator: "\n")

        let first = SummarizationPassPlanner.chunkTranscript(transcript, availableInputTokensPerPass: 160)
        let second = SummarizationPassPlanner.chunkTranscript(transcript, availableInputTokensPerPass: 160)

        #expect(first == second)
    }

    @Test
    func chunkTranscriptAllowsOversizedSingleLineProgress() {
        let hugeLine = String(repeating: "a", count: 8_000)
        let transcript = "\(hugeLine)\nsmall"

        let chunks = SummarizationPassPlanner.chunkTranscript(transcript, availableInputTokensPerPass: 128)

        #expect(chunks.count >= 2)
        #expect(chunks[0] == hugeLine)
    }

    @Test
    func estimateAllowsVeryHighPassCountWithoutHardCap() {
        let transcript = (0..<50_000)
            .map { "line-\($0) this is large content for stress testing pass estimation" }
            .joined(separator: "\n")

        let estimate = SummarizationPassPlanner.estimate(
            transcript: transcript,
            contextWindowTokens: 2048,
            reservedOutputTokens: 1024,
            safetyMarginTokens: 512,
            promptOverheadTokens: 256
        )

        #expect(estimate.estimatedPassCount > 100)
    }

    @Test
    func estimateRemainsUsableWhenRuntimeChunkCountDrifts() {
        let transcript = [
            String(repeating: "A", count: 600),
            String(repeating: "B", count: 600),
            String(repeating: "C", count: 600),
        ].joined(separator: "\n")

        let estimate = SummarizationPassPlanner.estimate(
            transcript: transcript,
            contextWindowTokens: 2048,
            reservedOutputTokens: 1024,
            safetyMarginTokens: 512,
            promptOverheadTokens: 256
        )
        let chunks = SummarizationPassPlanner.chunkTranscript(
            transcript,
            availableInputTokensPerPass: estimate.availableInputTokensPerPass
        )

        #expect(estimate.estimatedPassCount > 0)
        #expect(chunks.count > 0)
        #expect(chunks.count != estimate.estimatedPassCount)
        #expect(chunks == transcript.split(separator: "\n").map(String.init))
    }

    @Test
    func tokenBudgetEstimateEncodesUsingPreflightContractFieldNames() throws {
        let estimate = SummarizationTokenBudgetEstimate(
            runID: "run-123",
            modelID: "llama-3",
            contextWindowTokens: 4096,
            reservedOutputTokens: 1024,
            safetyMarginTokens: 256,
            promptOverheadTokens: 512,
            availableInputTokensPerPass: 2304,
            estimatedTotalInputTokens: 6400,
            estimatedPassCount: 3,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(estimate)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["runId"] as? String == "run-123")
        #expect(object["modelId"] as? String == "llama-3")
        #expect(object["contextWindowTokens"] as? Int == 4096)
        #expect(object["reservedOutputTokens"] as? Int == 1024)
        #expect(object["safetyMarginTokens"] as? Int == 256)
        #expect(object["promptOverheadTokens"] as? Int == 512)
        #expect(object["availableInputTokensPerPass"] as? Int == 2304)
        #expect(object["estimatedTotalInputTokens"] as? Int == 6400)
        #expect(object["estimatedPassCount"] as? Int == 3)
        #expect(object["createdAt"] != nil)
        #expect(object["runID"] == nil)
        #expect(object["modelID"] == nil)
    }

    @Test
    func chunkTranscriptReassemblesWithoutDuplicationOrLoss() {
        let lines = (0..<500).map { "[\($0)] deterministic content \($0 * 7)" }
        let transcript = lines.joined(separator: "\n")

        let chunks = SummarizationPassPlanner.chunkTranscript(transcript, availableInputTokensPerPass: 96)
        let rebuiltLines = chunks
            .flatMap { $0.split(separator: "\n", omittingEmptySubsequences: false) }
            .map(String.init)

        #expect(rebuiltLines == lines)
        #expect(Set(rebuiltLines).count == lines.count)
    }
}
