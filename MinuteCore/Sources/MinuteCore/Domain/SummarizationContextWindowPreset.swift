import Darwin
import Foundation

public enum SummarizationContextWindowPreset: String, Codable, Sendable, Equatable, Identifiable, CaseIterable {
    case automatic
    case low
    case balanced
    case high
    case maximum

    public var id: String { rawValue }

    public static var allCases: [SummarizationContextWindowPreset] {
        var presets: [SummarizationContextWindowPreset] = []
#if DEBUG
        presets.append(.low)
#endif
        presets.append(contentsOf: [.balanced, .high, .maximum])
        return presets
    }

    public var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .low:
            return "Low (4K)"
        case .balanced:
            return "Medium (8K)"
        case .high:
            return "High (32K)"
        case .maximum:
            return "Max (128K)"
        }
    }

    public var shortDisplayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .low:
            return "Low"
        case .balanced:
            return "Medium"
        case .high:
            return "High"
        case .maximum:
            return "Max"
        }
    }

    public var detailText: String {
        switch self {
        case .automatic:
            return "Uses the recommended context window for this Mac based on available RAM."
        case .low:
            return "Debug-only minimum context window for reproducing constrained-memory summarization behavior."
        case .balanced:
            return "Lower memory use. Recommended for 8 GB Macs."
        case .high:
            return "Larger context window with fewer summarization passes. Recommended for 16 GB Macs."
        case .maximum:
            return "Largest context window. Recommended for 32 GB and higher Macs."
        }
    }

    public var requestedContextTokens: Int? {
        switch self {
        case .automatic:
            return nil
        case .low:
            return 4_096
        case .balanced:
            return 8_192
        case .high:
            return 32_768
        case .maximum:
            return 131_072
        }
    }

    public func resolvedContextTokens(using hardwareProfile: SummarizationHardwareProfile) -> Int {
        if let requestedContextTokens {
            return requestedContextTokens
        }

        return hardwareProfile.recommendedPreset.requestedContextTokens ?? 8_192
    }
}

public struct SummarizationHardwareProfile: Sendable, Equatable {
    public var physicalMemoryBytes: UInt64
    public var isAppleSilicon: Bool

    public init(physicalMemoryBytes: UInt64, isAppleSilicon: Bool) {
        self.physicalMemoryBytes = physicalMemoryBytes
        self.isAppleSilicon = isAppleSilicon
    }

    public static func current(processInfo: ProcessInfo = .processInfo) -> SummarizationHardwareProfile {
        SummarizationHardwareProfile(
            physicalMemoryBytes: processInfo.physicalMemory,
            isAppleSilicon: hardwareFlag(named: "hw.optional.arm64") ?? false
        )
    }

    public var recommendedPreset: SummarizationContextWindowPreset {
        let gib = physicalMemoryBytes / 1_073_741_824

        if gib >= 32 {
            return .maximum
        }

        if gib >= 16 {
            return .high
        }

        return .balanced
    }

    private static func hardwareFlag(named name: String) -> Bool? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname(name, &value, &size, nil, 0)
        guard result == 0 else { return nil }
        return value == 1
    }
}
