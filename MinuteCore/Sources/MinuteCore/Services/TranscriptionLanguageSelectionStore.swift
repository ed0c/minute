import Foundation

public final class TranscriptionLanguageSelectionStore: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func selectedLanguage() -> TranscriptionLanguage {
        let rawValue = defaults.string(forKey: AppConfiguration.Defaults.transcriptionLanguageKey)
        return TranscriptionLanguage.resolved(from: rawValue)
    }

    public func setSelectedLanguage(_ language: TranscriptionLanguage) {
        defaults.set(language.rawValue, forKey: AppConfiguration.Defaults.transcriptionLanguageKey)
    }
}
