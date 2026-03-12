import Foundation
import Testing
@testable import MinuteCore

struct SummarizationContextWindowPresetTests {
    @Test
    func allCases_exposesLowPresetOnlyInDebugBuilds() {
#if DEBUG
        #expect(SummarizationContextWindowPreset.allCases.contains(.low))
#else
        #expect(!SummarizationContextWindowPreset.allCases.contains(.low))
#endif
    }

    @Test
    func recommendation_usesBalancedFor8GBMachines() {
        let profile = SummarizationHardwareProfile(
            physicalMemoryBytes: 8 * 1_073_741_824,
            isAppleSilicon: true
        )

        #expect(profile.recommendedPreset == .balanced)
        #expect(profile.recommendedPreset.requestedContextTokens == 8_192)
    }

    @Test
    func recommendation_usesHighFor16GBMachines() {
        let profile = SummarizationHardwareProfile(
            physicalMemoryBytes: 16 * 1_073_741_824,
            isAppleSilicon: true
        )

        #expect(profile.recommendedPreset == .high)
        #expect(profile.recommendedPreset.requestedContextTokens == 32_768)
    }

    @Test
    func recommendation_usesMaximumFor32GBMachines() {
        let profile = SummarizationHardwareProfile(
            physicalMemoryBytes: 32 * 1_073_741_824,
            isAppleSilicon: true
        )

        #expect(profile.recommendedPreset == .maximum)
        #expect(profile.recommendedPreset.requestedContextTokens == 131_072)
    }

    @Test
    func selectionStore_defaultsToHardwareRecommendationWhenUnset() throws {
        let suite = "SummarizationContextWindowPresetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SummarizationContextWindowSelectionStore(
            defaults: defaults,
            key: "ctx",
            hardwareProfileProvider: {
                SummarizationHardwareProfile(
                    physicalMemoryBytes: 16 * 1_073_741_824,
                    isAppleSilicon: true
                )
            }
        )
        #expect(store.selectedPreset() == .high)
    }

    @Test
    func selectionStore_persistsPreset() throws {
        let suite = "SummarizationContextWindowPresetTests.persist.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx")

        store.setSelectedPreset(.high)

        #expect(store.selectedPreset() == .high)
    }

    @Test
    func selectionStore_migratesLegacyAutomaticToHardwareRecommendation() throws {
        let suite = "SummarizationContextWindowPresetTests.automatic.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(SummarizationContextWindowPreset.automatic.rawValue, forKey: "ctx")

        let store = SummarizationContextWindowSelectionStore(
            defaults: defaults,
            key: "ctx",
            hardwareProfileProvider: {
                SummarizationHardwareProfile(
                    physicalMemoryBytes: 32 * 1_073_741_824,
                    isAppleSilicon: true
                )
            }
        )

        #expect(store.selectedPreset() == .maximum)
    }

    @Test
    func selectionStore_handlesLowPresetPerBuildConfiguration() throws {
        let suite = "SummarizationContextWindowPresetTests.migration.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(SummarizationContextWindowPreset.low.rawValue, forKey: "ctx")

        let store = SummarizationContextWindowSelectionStore(defaults: defaults, key: "ctx")

#if DEBUG
        #expect(store.selectedPreset() == .low)
#else
        #expect(store.selectedPreset() == .balanced)
#endif
    }
}
