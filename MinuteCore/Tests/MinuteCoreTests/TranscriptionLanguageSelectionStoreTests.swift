import Foundation
import Testing
@testable import MinuteCore

struct TranscriptionLanguageSelectionStoreTests {
    @Test
    func selectedLanguage_defaultsToAuto() {
        let suite = "transcription-language-selection-store-default-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TranscriptionLanguageSelectionStore(defaults: defaults)
        expectEqual(store.selectedLanguage(), .auto)
    }

    @Test
    func setSelectedLanguage_persistsSelection() {
        let suite = "transcription-language-selection-store-set-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TranscriptionLanguageSelectionStore(defaults: defaults)
        store.setSelectedLanguage(.norwegian)

        expectEqual(store.selectedLanguage(), .norwegian)
    }

    @Test
    func selectedLanguage_invalidStoredValue_fallsBackToAuto() {
        let suite = "transcription-language-selection-store-invalid-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("not-a-language", forKey: AppConfiguration.Defaults.transcriptionLanguageKey)

        let store = TranscriptionLanguageSelectionStore(defaults: defaults)
        expectEqual(store.selectedLanguage(), .auto)
    }
}
