import Foundation

public enum ResolvedPromptBundleResolverError: Error, Sendable, Equatable {
    case selectedTypeUnavailable(String)
}

public struct ResolvedPromptBundleResolver: ResolvedPromptBundleResolving {
    public init() {}

    public func resolvePromptBundle(
        library: MeetingTypeLibrary,
        selection: MeetingTypeSelection,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        autodetectResolvedTypeID: String? = nil
    ) throws -> ResolvedPromptBundle {
        let requestedTypeID: String = {
            switch selection.selectionMode {
            case .manual:
                return selection.selectedTypeId
            case .autodetect:
                return (autodetectResolvedTypeID?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
                    $0.isEmpty ? nil : $0
                } ?? MeetingType.general.rawValue
            }
        }()

        let definition: MeetingTypeDefinition
        switch selection.selectionMode {
        case .manual:
            guard let resolved = library.definition(for: requestedTypeID), resolved.status == .active else {
                throw ResolvedPromptBundleResolverError.selectedTypeUnavailable(requestedTypeID)
            }
            definition = resolved
        case .autodetect:
            if let resolved = library.definition(for: requestedTypeID), resolved.status == .active {
                definition = resolved
            } else if let fallbackGeneral = library.definition(for: MeetingType.general.rawValue),
                      fallbackGeneral.status == .active {
                definition = fallbackGeneral
            } else if let firstActive = library.activeDefinitions.first {
                definition = firstActive
            } else {
                throw ResolvedPromptBundleResolverError.selectedTypeUnavailable(requestedTypeID)
            }
        }

        let sourceKind = resolveSourceKind(library: library, definition: definition)
        let prompts = resolvePromptContent(
            sourceKind: sourceKind,
            definition: definition,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage
        )

        return ResolvedPromptBundle(
            typeId: definition.typeId,
            typeDisplayName: definition.displayName,
            systemPrompt: prompts.systemPrompt,
            userPromptPreamble: prompts.userPromptPreamble,
            runtimeLanguageMode: languageProcessing.rawValue,
            runtimeOutputLanguage: outputLanguage.rawValue,
            sourceKind: sourceKind
        )
    }

    private func resolveSourceKind(
        library: MeetingTypeLibrary,
        definition: MeetingTypeDefinition
    ) -> ResolvedPromptSourceKind {
        switch definition.source {
        case .custom:
            return .custom
        case .builtIn:
            return library.isBuiltInOverridden(typeID: definition.typeId)
                ? .builtInOverride
                : .builtInDefault
        }
    }

    private func resolvePromptContent(
        sourceKind: ResolvedPromptSourceKind,
        definition: MeetingTypeDefinition,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) -> (systemPrompt: String, userPromptPreamble: String) {
        if sourceKind == .builtInDefault, let builtInType = MeetingType(rawValue: definition.typeId) {
            let strategy = PromptFactory.strategy(for: builtInType)
            let systemPrompt = PromptFactory.systemPrompt(
                strategy: strategy,
                languageProcessing: languageProcessing,
                outputLanguage: outputLanguage
            )
            let userPromptPreamble = PromptFactory.userPromptPreamble(
                strategy: strategy,
                languageProcessing: languageProcessing,
                outputLanguage: outputLanguage
            )
            return (systemPrompt, userPromptPreamble)
        }

        let systemPrompt = PromptFactory.systemPrompt(
            promptComponents: definition.promptComponents,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage
        )
        let userPromptPreamble = PromptFactory.userPromptPreamble(
            promptComponents: definition.promptComponents,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage
        )
        return (systemPrompt, userPromptPreamble)
    }
}
