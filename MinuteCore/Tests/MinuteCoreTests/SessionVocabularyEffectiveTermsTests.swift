import Testing
@testable import MinuteCore

struct SessionVocabularyEffectiveTermsTests {
    private let resolver = SessionVocabularyResolver()

    @Test
    func customTerms_addOnToGlobalTerms() {
        let global = GlobalVocabularyBoostingSettings(
            enabled: true,
            strength: .balanced,
            terms: ["Apollo", "Roadmap"]
        )

        let resolved = resolver.resolve(
            globalSettings: global,
            sessionMode: .custom,
            sessionCustomInput: "Taylor\napollo, Q4",
            readiness: .ready(backend: .fluidAudio)
        )

        expectEqual(resolved.effectiveMode, .custom)
        expectEqual(resolved.effectiveTerms, ["Apollo", "Roadmap", "Taylor", "Q4"])
    }

    @Test
    func emptyCustomInput_behavesAsDefaultMode() {
        let global = GlobalVocabularyBoostingSettings(
            enabled: true,
            strength: .gentle,
            terms: ["Apollo"]
        )

        let resolved = resolver.resolve(
            globalSettings: global,
            sessionMode: .custom,
            sessionCustomInput: "  \n, ",
            readiness: .ready(backend: .fluidAudio)
        )

        expectEqual(resolved.effectiveMode, .default)
        expectEqual(resolved.effectiveTerms, ["Apollo"])
        expectEqual(resolved.effectiveStrength, .gentle)
    }
}
