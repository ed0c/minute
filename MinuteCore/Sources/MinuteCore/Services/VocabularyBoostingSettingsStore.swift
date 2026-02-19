import Foundation

public final class VocabularyBoostingSettingsStore: VocabularyBoostingSettingsStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let enabledKey: String
    private let termsKey: String
    private let strengthKey: String
    private let updatedAtKey: String

    public init(
        defaults: UserDefaults = .standard,
        enabledKey: String = AppConfiguration.Defaults.vocabularyBoostingEnabledKey,
        termsKey: String = AppConfiguration.Defaults.vocabularyBoostingTermsKey,
        strengthKey: String = AppConfiguration.Defaults.vocabularyBoostingStrengthKey,
        updatedAtKey: String = AppConfiguration.Defaults.vocabularyBoostingUpdatedAtKey
    ) {
        self.defaults = defaults
        self.enabledKey = enabledKey
        self.termsKey = termsKey
        self.strengthKey = strengthKey
        self.updatedAtKey = updatedAtKey
    }

    public func load() -> GlobalVocabularyBoostingSettings {
        let enabled = defaults.object(forKey: enabledKey) as? Bool
            ?? AppConfiguration.Defaults.defaultVocabularyBoostingEnabled
        let rawTerms = defaults.stringArray(forKey: termsKey) ?? []
        let normalizedTerms = VocabularyTermEntry.normalizeDisplayTerms(rawTerms)

        let strengthRaw = defaults.string(forKey: strengthKey) ?? ""
        let strength = VocabularyBoostingStrength(rawValue: strengthRaw)
            ?? AppConfiguration.Defaults.defaultVocabularyBoostingStrength

        let updatedAt = defaults.object(forKey: updatedAtKey) as? Date ?? .distantPast

        return GlobalVocabularyBoostingSettings(
            enabled: enabled,
            strength: strength,
            terms: normalizedTerms,
            updatedAt: updatedAt
        )
    }

    public func save(_ settings: GlobalVocabularyBoostingSettings) {
        defaults.set(settings.enabled, forKey: enabledKey)
        defaults.set(settings.strength.rawValue, forKey: strengthKey)
        defaults.set(VocabularyTermEntry.normalizeDisplayTerms(settings.terms), forKey: termsKey)
        defaults.set(settings.updatedAt, forKey: updatedAtKey)
    }

    public func clear() {
        defaults.removeObject(forKey: enabledKey)
        defaults.removeObject(forKey: termsKey)
        defaults.removeObject(forKey: strengthKey)
        defaults.removeObject(forKey: updatedAtKey)
    }
}
