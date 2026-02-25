import Foundation
import Testing
@testable import MinuteCore

struct MarkdownRendererSectionVisibilityTests {
    @Test
    func render_omitsDisabledSectionsFromBody() {
        let extraction = MeetingExtraction(
            title: "Weekly Sync",
            date: "2025-12-19",
            summary: "We aligned on next steps.",
            decisions: ["Ship v1"],
            actionItems: [ActionItem(owner: "Alex", task: "Draft release notes")],
            openQuestions: ["Do we need ffmpeg?"],
            keyPoints: ["Local-only processing"]
        )

        let markdown = MarkdownRenderer().render(
            extraction: extraction,
            noteDateTime: "2025-12-19 09:00",
            audioDurationSeconds: nil,
            audioRelativePath: nil,
            transcriptRelativePath: nil,
            sectionVisibility: MeetingSummarySectionVisibility(
                decisions: false,
                actionItems: true,
                openQuestions: false,
                keyPoints: true
            )
        )

        #expect(!markdown.contains("## Decisions"))
        #expect(!markdown.contains("## Open Questions"))
        #expect(markdown.contains("## Action Items"))
        #expect(markdown.contains("## Key Points"))
    }
}
