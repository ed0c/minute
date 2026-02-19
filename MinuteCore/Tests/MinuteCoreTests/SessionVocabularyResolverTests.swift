import Testing
@testable import MinuteCore

struct SessionVocabularyResolverTests {
    private let resolver = SessionVocabularyResolver()

    @Test
    func customMode_addsSessionTermsOnTopOfGlobal() {
        let global = GlobalVocabularyBoostingSettings(
            enabled: true,
            strength: .balanced,
            terms: ["Acme", "Roadmap"]
        )
        let readiness = VocabularyReadinessStatus.ready(backend: .fluidAudio)

        let resolved = resolver.resolve(
            globalSettings: global,
            sessionMode: .custom,
            sessionCustomInput: "Taylor\nacme,Launch",
            readiness: readiness
        )

        expectEqual(resolved.effectiveMode, .custom)
        expectEqual(resolved.effectiveTerms, ["Acme", "Roadmap", "Taylor", "Launch"])
        expectEqual(resolved.effectiveStrength, .balanced)
    }

    @Test
    func customMode_emptyCustomFallsBackToDefault() {
        let global = GlobalVocabularyBoostingSettings(
            enabled: true,
            strength: .gentle,
            terms: ["Acme"]
        )
        let readiness = VocabularyReadinessStatus.ready(backend: .fluidAudio)

        let resolved = resolver.resolve(
            globalSettings: global,
            sessionMode: .custom,
            sessionCustomInput: "\n ,  ",
            readiness: readiness
        )

        expectEqual(resolved.effectiveMode, .default)
        expectEqual(resolved.effectiveTerms, ["Acme"])
        expectEqual(resolved.warningMessage, nil)
    }

    @Test
    func missingModels_disablesVocabularyAndSetsWarning() {
        let global = GlobalVocabularyBoostingSettings(
            enabled: true,
            strength: .aggressive,
            terms: ["Acme"]
        )
        let readiness = VocabularyReadinessStatus.missingModels(
            backend: .fluidAudio,
            message: "Vocabulary models missing"
        )

        let resolved = resolver.resolve(
            globalSettings: global,
            sessionMode: .default,
            sessionCustomInput: "Taylor",
            readiness: readiness
        )

        expectEqual(resolved.effectiveMode, .off)
        expectEqual(resolved.effectiveTerms, [])
        expectEqual(resolved.warningMessage, "Vocabulary models missing")
    }

    @Test
    func unsupportedBackend_forcesOff() {
        let global = GlobalVocabularyBoostingSettings(
            enabled: true,
            strength: .balanced,
            terms: ["Acme"]
        )

        let resolved = resolver.resolve(
            globalSettings: global,
            sessionMode: .default,
            sessionCustomInput: "Taylor",
            readiness: .unsupported(backend: .whisper)
        )

        expectEqual(resolved.effectiveMode, .off)
        expectEqual(resolved.effectiveTerms, [])
    }
}
