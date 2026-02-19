import Testing
@testable import MinuteCore

struct VocabularyTermNormalizationTests {
    @Test
    func parseFromEditorInput_splitsCommaAndNewline_andDeduplicatesCaseInsensitive() {
        let input = "Acme, roadmap\n ROADMAP\n\nTaylor"

        let parsed = VocabularyTermEntry.parseFromEditorInput(input, source: .global)

        expectEqual(parsed.map(\.displayText), ["Acme", "roadmap", "Taylor"])
    }

    @Test
    func normalizeDisplayTerms_trimsWhitespace_andDropsEmpty() {
        let normalized = VocabularyTermEntry.normalizeDisplayTerms([
            "  Acme  ",
            "",
            "   ",
            "Roadmap"
        ])

        expectEqual(normalized, ["Acme", "Roadmap"])
    }
}
