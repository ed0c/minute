import Foundation
import Testing
@testable import Minute

@MainActor
struct MeetingPipelineViewModelSummarizationProgressDetailTests {
    @Test
    func singlePassEstimate_isHidden() {
        let detail = MeetingPipelineViewModel.formatSummarizationProgressDetail(
            estimatedPassCount: 1,
            currentPassIndex: nil,
            totalPassCount: nil,
            resumedFromPassIndex: nil
        )

        #expect(detail == nil)
    }

    @Test
    func multiPassEstimate_isShownWithoutTokenBudget() {
        let detail = MeetingPipelineViewModel.formatSummarizationProgressDetail(
            estimatedPassCount: 3,
            currentPassIndex: 2,
            totalPassCount: 4,
            resumedFromPassIndex: nil
        )

        #expect(detail == "Estimated passes: 3 • Pass 2 of 4")
        #expect(detail?.contains("Budget") == false)
    }

    @Test
    func resumedRun_showsResumeAndCurrentPass_withoutEstimateForSinglePass() {
        let detail = MeetingPipelineViewModel.formatSummarizationProgressDetail(
            estimatedPassCount: 1,
            currentPassIndex: 2,
            totalPassCount: 4,
            resumedFromPassIndex: 2
        )

        #expect(detail == "Resuming from pass 2 • Pass 2 of 4")
    }
}
