import Foundation

public struct SessionVocabularyResolution: Sendable, Equatable {
    public var requestedMode: VocabularyBoostingSessionMode
    public var effectiveMode: VocabularyBoostingSessionMode
    public var effectiveTerms: [String]
    public var effectiveStrength: VocabularyBoostingStrength?
    public var warningMessage: String?

    public init(
        requestedMode: VocabularyBoostingSessionMode,
        effectiveMode: VocabularyBoostingSessionMode,
        effectiveTerms: [String],
        effectiveStrength: VocabularyBoostingStrength?,
        warningMessage: String? = nil
    ) {
        self.requestedMode = requestedMode
        self.effectiveMode = effectiveMode
        self.effectiveTerms = effectiveTerms
        self.effectiveStrength = effectiveStrength
        self.warningMessage = warningMessage
    }

    public var transcriptionVocabulary: TranscriptionVocabularySettings? {
        guard effectiveMode != .off else { return nil }
        return TranscriptionVocabularySettings(
            mode: effectiveMode,
            terms: effectiveTerms,
            strength: effectiveStrength
        )
    }
}

public struct SessionVocabularyResolver: SessionVocabularyResolving {
    public init() {}

    public func resolve(
        globalSettings: GlobalVocabularyBoostingSettings,
        sessionMode: VocabularyBoostingSessionMode,
        sessionCustomInput: String,
        readiness: VocabularyReadinessStatus
    ) -> SessionVocabularyResolution {
        guard readiness.isSupported else {
            return SessionVocabularyResolution(
                requestedMode: sessionMode,
                effectiveMode: .off,
                effectiveTerms: [],
                effectiveStrength: nil
            )
        }

        if readiness.state == .missingModels {
            return SessionVocabularyResolution(
                requestedMode: sessionMode,
                effectiveMode: .off,
                effectiveTerms: [],
                effectiveStrength: nil,
                warningMessage: readiness.message
            )
        }

        let globalTerms = globalSettings.enabled ? globalSettings.terms : []
        let customTerms = VocabularyTermEntry.parseFromEditorInput(sessionCustomInput, source: .sessionCustom)
            .map(\.displayText)

        switch sessionMode {
        case .off:
            return SessionVocabularyResolution(
                requestedMode: .off,
                effectiveMode: .off,
                effectiveTerms: [],
                effectiveStrength: nil
            )
        case .default:
            return SessionVocabularyResolution(
                requestedMode: .default,
                effectiveMode: .default,
                effectiveTerms: globalTerms,
                effectiveStrength: globalSettings.enabled ? globalSettings.strength : nil
            )
        case .custom:
            if customTerms.isEmpty {
                return SessionVocabularyResolution(
                    requestedMode: .custom,
                    effectiveMode: .default,
                    effectiveTerms: globalTerms,
                    effectiveStrength: globalSettings.enabled ? globalSettings.strength : nil
                )
            }

            let merged = VocabularyTermEntry.normalizeDisplayTerms(globalTerms + customTerms)
            return SessionVocabularyResolution(
                requestedMode: .custom,
                effectiveMode: .custom,
                effectiveTerms: merged,
                effectiveStrength: globalSettings.strength
            )
        }
    }
}
