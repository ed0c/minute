import Foundation

public struct WhisperLanguageAttempt: Sendable, Equatable {
    public var detectLanguage: Bool
    public var languageCode: String?

    public init(detectLanguage: Bool, languageCode: String?) {
        self.detectLanguage = detectLanguage
        self.languageCode = languageCode
    }
}

public enum WhisperLanguageAttemptPlanner {
    public static func effectiveLanguage(
        languageOverride: TranscriptionLanguage?,
        storedLanguage: TranscriptionLanguage
    ) -> TranscriptionLanguage {
        languageOverride ?? storedLanguage
    }

    public static func languageAttempts(selectedLanguage: TranscriptionLanguage) -> [WhisperLanguageAttempt] {
        var attempts: [WhisperLanguageAttempt] = [
            WhisperLanguageAttempt(
                detectLanguage: selectedLanguage.detectLanguage,
                languageCode: selectedLanguage.whisperLanguageCode
            )
        ]

        // If the first attempt yields an empty transcript, retry once in English.
        if selectedLanguage != .english {
            attempts.append(WhisperLanguageAttempt(detectLanguage: false, languageCode: "en"))
        }

        return attempts
    }
}
