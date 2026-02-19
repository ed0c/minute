import Foundation
import Testing
@testable import MinuteCore

struct VocabularyBoostingSettingsStoreTests {
    @Test
    func load_defaultsWhenUnset() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)

        let loaded = store.load()

        expectEqual(loaded.enabled, AppConfiguration.Defaults.defaultVocabularyBoostingEnabled)
        expectEqual(loaded.strength, AppConfiguration.Defaults.defaultVocabularyBoostingStrength)
        expectEqual(loaded.terms, [])
    }

    @Test
    func saveThenLoad_normalizesTerms() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)

        store.save(
            GlobalVocabularyBoostingSettings(
                enabled: true,
                strength: .aggressive,
                terms: ["  Acme  ", "ACME", "Roadmap", ""]
            )
        )

        let loaded = store.load()
        expectEqual(loaded.enabled, true)
        expectEqual(loaded.strength, .aggressive)
        expectEqual(loaded.terms, ["Acme", "Roadmap"])
    }

    @Test
    func clear_restoresDefaults() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)

        store.save(
            GlobalVocabularyBoostingSettings(
                enabled: true,
                strength: .gentle,
                terms: ["Release train"]
            )
        )

        store.clear()
        let loaded = store.load()

        expectEqual(loaded.enabled, AppConfiguration.Defaults.defaultVocabularyBoostingEnabled)
        expectEqual(loaded.strength, AppConfiguration.Defaults.defaultVocabularyBoostingStrength)
        expectEqual(loaded.terms, [])
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "VocabularyBoostingSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeStore(defaults: UserDefaults) -> VocabularyBoostingSettingsStore {
        VocabularyBoostingSettingsStore(
            defaults: defaults,
            enabledKey: "enabled",
            termsKey: "terms",
            strengthKey: "strength",
            updatedAtKey: "updatedAt"
        )
    }
}
