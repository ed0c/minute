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

        guard globalSettings.enabled else {
            return SessionVocabularyResolution(
                requestedMode: sessionMode,
                effectiveMode: .off,
                effectiveTerms: [],
                effectiveStrength: nil
            )
        }

        let globalTerms = globalSettings.terms
        let customTerms = VocabularyTermEntry.parseFromEditorInput(sessionCustomInput, source: .sessionCustom)
            .map(\.displayText)

        if customTerms.isEmpty {
            return SessionVocabularyResolution(
                requestedMode: sessionMode,
                effectiveMode: .default,
                effectiveTerms: globalTerms,
                effectiveStrength: globalSettings.strength
            )
        }

        let merged = VocabularyTermEntry.normalizeDisplayTerms(globalTerms + customTerms)
        return SessionVocabularyResolution(
            requestedMode: sessionMode,
            effectiveMode: .custom,
            effectiveTerms: merged,
            effectiveStrength: globalSettings.strength
        )
    }
}
