import Testing
@testable import MinuteCore

struct TranscriptionLanguageTests {
    @Test
    func defaultSelection_isAuto() {
        expectEqual(TranscriptionLanguage.defaultSelection, .auto)
    }

    @Test
    func resolved_whenRawValueMissingOrInvalid_fallsBackToDefault() {
        expectEqual(TranscriptionLanguage.resolved(from: nil), .auto)
        expectEqual(TranscriptionLanguage.resolved(from: "invalid"), .auto)
    }

    @Test
    func resolved_whenRawValueValid_returnsLanguage() {
        expectEqual(TranscriptionLanguage.resolved(from: "en"), .english)
        expectEqual(TranscriptionLanguage.resolved(from: "no"), .norwegian)
    }

    @Test
    func detectLanguage_isTrueOnlyForAuto() {
        #expect(TranscriptionLanguage.auto.detectLanguage)
        #expect(TranscriptionLanguage.english.detectLanguage == false)
        #expect(TranscriptionLanguage.norwegian.detectLanguage == false)
    }

    @Test
    func whisperLanguageCode_matchesSelectedLanguage() {
        expectEqual(TranscriptionLanguage.auto.whisperLanguageCode, nil)
        expectEqual(TranscriptionLanguage.english.whisperLanguageCode, "en")
        expectEqual(TranscriptionLanguage.norwegian.whisperLanguageCode, "no")
    }
}
