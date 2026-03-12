import Foundation
import Testing
@testable import MinuteCore

struct SummarizationSummaryMergerTests {
    @Test
    func merge_replacesOverlappingSummaryWithMoreInformativeVersion() {
        let recordingDate = Date(timeIntervalSince1970: 1_700_000_000)
        let first = SummarizationSummaryMerger.merge(
            previousState: nil,
            delta: SummarizationPassDelta(
                title: "Kitchen Planner",
                date: "2025-12-26",
                summaryPoints: ["Feature rollout plan was approved."],
                decisions: ["Roll out to beta users first."]
            ),
            meetingType: .planning,
            recordingDate: recordingDate
        )

        let second = SummarizationSummaryMerger.merge(
            previousState: first,
            delta: SummarizationPassDelta(
                summaryPoints: ["Feature rollout plan was approved with a beta-first launch in October."],
                decisions: ["Roll out to beta users first."]
            ),
            meetingType: .planning,
            recordingDate: recordingDate
        )

        #expect(second.summaryPoints == ["Feature rollout plan was approved with a beta-first launch in October."])
        #expect(second.decisions == ["Roll out to beta users first."])

        let extraction = SummarizationSummaryMerger.extraction(from: second, recordingDate: recordingDate)
        #expect(extraction.summary == "Feature rollout plan was approved with a beta-first launch in October.")
    }

    @Test
    func merge_appendsDistinctNewInformationWithoutRepeatingEarlierItems() {
        let recordingDate = Date(timeIntervalSince1970: 1_700_000_000)
        let first = SummarizationSummaryMerger.merge(
            previousState: nil,
            delta: SummarizationPassDelta(summaryPoints: ["Mobile launch remains on track."]),
            meetingType: .general,
            recordingDate: recordingDate
        )

        let second = SummarizationSummaryMerger.merge(
            previousState: first,
            delta: SummarizationPassDelta(summaryPoints: ["Docs updates must be complete before launch."]),
            meetingType: .general,
            recordingDate: recordingDate
        )

        let extraction = SummarizationSummaryMerger.extraction(from: second, recordingDate: recordingDate)
        #expect(extraction.summary.contains("Mobile launch remains on track."))
        #expect(extraction.summary.contains("Docs updates must be complete before launch."))
        #expect(second.summaryPoints.count == 2)
    }
}
