import Testing
@testable import MinuteCore

struct WhisperLanguageAttemptPlannerTests {
    @Test
    func effectiveLanguage_usesStoredLanguageWhenNoOverride() {
        let resolved = WhisperLanguageAttemptPlanner.effectiveLanguage(
            languageOverride: nil,
            storedLanguage: .norwegian
        )
        expectEqual(resolved, .norwegian)
    }

    @Test
    func effectiveLanguage_prefersOverrideWhenProvided() {
        let resolved = WhisperLanguageAttemptPlanner.effectiveLanguage(
            languageOverride: .english,
            storedLanguage: .norwegian
        )
        expectEqual(resolved, .english)
    }

    @Test
    func languageAttempts_autoIncludesEnglishFallback() {
        let attempts = WhisperLanguageAttemptPlanner.languageAttempts(selectedLanguage: .auto)
        expectEqual(
            attempts,
            [
                WhisperLanguageAttempt(detectLanguage: true, languageCode: nil),
                WhisperLanguageAttempt(detectLanguage: false, languageCode: "en"),
            ]
        )
    }

    @Test
    func languageAttempts_specificLanguageIncludesEnglishFallback() {
        let attempts = WhisperLanguageAttemptPlanner.languageAttempts(selectedLanguage: .norwegian)
        expectEqual(
            attempts,
            [
                WhisperLanguageAttempt(detectLanguage: false, languageCode: "no"),
                WhisperLanguageAttempt(detectLanguage: false, languageCode: "en"),
            ]
        )
    }

    @Test
    func languageAttempts_englishDoesNotDuplicateFallback() {
        let attempts = WhisperLanguageAttemptPlanner.languageAttempts(selectedLanguage: .english)
        expectEqual(
            attempts,
            [WhisperLanguageAttempt(detectLanguage: false, languageCode: "en")]
        )
    }
}
