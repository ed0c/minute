import Foundation

public enum VocabularyBoostingStrength: String, CaseIterable, Codable, Sendable, Equatable, Identifiable {
    case gentle
    case balanced
    case aggressive

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gentle:
            return "Gentle"
        case .balanced:
            return "Balanced"
        case .aggressive:
            return "Aggressive"
        }
    }
}

public enum VocabularyBoostingSessionMode: String, CaseIterable, Codable, Sendable, Equatable, Identifiable {
    case off
    case `default`
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off:
            return "Off"
        case .default:
            return "Default"
        case .custom:
            return "Custom"
        }
    }
}

public enum VocabularyReadinessState: String, Sendable, Equatable {
    case ready
    case missingModels
    case unsupported
}

public struct VocabularyReadinessStatus: Sendable, Equatable {
    public var backend: TranscriptionBackend
    public var state: VocabularyReadinessState
    public var message: String?

    public init(
        backend: TranscriptionBackend,
        state: VocabularyReadinessState,
        message: String? = nil
    ) {
        self.backend = backend
        self.state = state
        self.message = message
    }

    public var isSupported: Bool {
        backend == .fluidAudio
    }

    public static func ready(backend: TranscriptionBackend) -> VocabularyReadinessStatus {
        VocabularyReadinessStatus(backend: backend, state: .ready)
    }

    public static func missingModels(
        backend: TranscriptionBackend,
        message: String
    ) -> VocabularyReadinessStatus {
        VocabularyReadinessStatus(backend: backend, state: .missingModels, message: message)
    }

    public static func unsupported(backend: TranscriptionBackend) -> VocabularyReadinessStatus {
        VocabularyReadinessStatus(backend: backend, state: .unsupported)
    }
}

public struct VocabularyTermEntry: Codable, Sendable, Equatable, Hashable {
    private static let normalizationLocale = Locale(identifier: "en_US_POSIX")

    public enum Source: String, Codable, Sendable, Equatable {
        case global
        case sessionCustom
    }

    public var displayText: String
    public var normalizedKey: String
    public var source: Source

    public init(displayText: String, source: Source) {
        let trimmed = displayText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayText = trimmed
        self.normalizedKey = VocabularyTermEntry.normalizedKey(for: trimmed)
        self.source = source
    }

    public static func normalizedKey(for value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: normalizationLocale)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: normalizationLocale)
    }

    public static func normalizeDisplayTerms(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var normalized: [String] = []
        normalized.reserveCapacity(values.count)

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = normalizedKey(for: trimmed)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            normalized.append(trimmed)
        }

        return normalized
    }

    public static func parseFromEditorInput(_ input: String, source: Source) -> [VocabularyTermEntry] {
        let csvReady = input.replacingOccurrences(of: "\n", with: ",")
        let split = csvReady.split(separator: ",", omittingEmptySubsequences: false)

        var seen: Set<String> = []
        var entries: [VocabularyTermEntry] = []
        entries.reserveCapacity(split.count)

        for item in split {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = normalizedKey(for: trimmed)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            entries.append(VocabularyTermEntry(displayText: trimmed, source: source))
        }

        return entries
    }
}

public struct GlobalVocabularyBoostingSettings: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var strength: VocabularyBoostingStrength
    public var terms: [String]
    public var updatedAt: Date

    public init(
        enabled: Bool,
        strength: VocabularyBoostingStrength,
        terms: [String],
        updatedAt: Date = Date()
    ) {
        self.enabled = enabled
        self.strength = strength
        self.terms = VocabularyTermEntry.normalizeDisplayTerms(terms)
        self.updatedAt = updatedAt
    }

    public static var `default`: GlobalVocabularyBoostingSettings {
        GlobalVocabularyBoostingSettings(
            enabled: AppConfiguration.Defaults.defaultVocabularyBoostingEnabled,
            strength: AppConfiguration.Defaults.defaultVocabularyBoostingStrength,
            terms: []
        )
    }

    public var editorInput: String {
        terms.joined(separator: "\n")
    }
}
