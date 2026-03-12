import Foundation

public final class SummarizationContextWindowSelectionStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let hardwareProfileProvider: @Sendable () -> SummarizationHardwareProfile

    public init(
        defaults: UserDefaults = .standard,
        key: String = AppConfiguration.Defaults.summarizationContextWindowPresetKey,
        hardwareProfileProvider: @escaping @Sendable () -> SummarizationHardwareProfile = { .current() }
    ) {
        self.defaults = defaults
        self.key = key
        self.hardwareProfileProvider = hardwareProfileProvider
    }

    public func selectedPreset() -> SummarizationContextWindowPreset {
        guard let rawValue = defaults.string(forKey: key),
              let preset = SummarizationContextWindowPreset(rawValue: rawValue)
        else {
            return recommendedPreset()
        }

        if preset == .automatic {
            return recommendedPreset()
        }

        if preset == .low {
#if DEBUG
            return .low
#else
            return .balanced
#endif
        }

        return preset
    }

    public func setSelectedPreset(_ preset: SummarizationContextWindowPreset) {
        let normalizedPreset: SummarizationContextWindowPreset
        if preset == .low {
#if DEBUG
            normalizedPreset = .low
#else
            normalizedPreset = .balanced
#endif
        } else {
            normalizedPreset = preset
        }
        defaults.set(normalizedPreset.rawValue, forKey: key)
    }

    public func clearSelectedPreset() {
        defaults.removeObject(forKey: key)
    }

    public func recommendedPreset(
        hardwareProfile: SummarizationHardwareProfile? = nil
    ) -> SummarizationContextWindowPreset {
        (hardwareProfile ?? hardwareProfileProvider()).recommendedPreset
    }

    public func requestedContextTokens(
        hardwareProfile: SummarizationHardwareProfile? = nil
    ) -> Int {
        selectedPreset().resolvedContextTokens(using: hardwareProfile ?? hardwareProfileProvider())
    }
}
