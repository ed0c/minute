import Testing
@testable import MinuteCore

struct ResolvedPromptBundleResolverTests {
    @Test
    func resolvePromptBundle_forCustomManualSelection_isDeterministic() throws {
        let custom = PromptLibraryFixture.customDefinition(
            typeId: "custom-discovery",
            displayName: "Discovery Sync",
            promptComponents: PromptLibraryFixture.promptComponents(
                objective: "Summarize customer discovery findings.",
                summaryFocus: "Prioritize insights and owners.",
                decisionRules: "Capture confirmed directional decisions.",
                actionItemRules: "List owner and due context if present."
            )
        )
        let library = PromptLibraryFixture.defaultLibraryWithCustom(custom: custom)
        let selection = MeetingTypeSelection(selectionMode: .manual, selectedTypeId: custom.typeId)
        let resolver = ResolvedPromptBundleResolver()

        let first = try resolver.resolvePromptBundle(
            library: library,
            selection: selection,
            languageProcessing: .autoToEnglish,
            outputLanguage: .defaultSelection
        )
        let second = try resolver.resolvePromptBundle(
            library: library,
            selection: selection,
            languageProcessing: .autoToEnglish,
            outputLanguage: .defaultSelection
        )

        expectEqual(first, second)
        expectEqual(first.sourceKind, .custom)
        #expect(first.systemPrompt.contains("Summarize customer discovery findings."))
        #expect(first.systemPrompt.contains("Prioritize insights and owners."))
        #expect(first.userPromptPreamble.contains("Timeline follows:"))
    }

    @Test
    func resolvePromptBundle_forBuiltInDefault_usesBuiltInSourceKind() throws {
        let library = MeetingTypeLibrary.default
        let resolver = ResolvedPromptBundleResolver()
        let selection = MeetingTypeSelection(selectionMode: .manual, selectedTypeId: MeetingType.general.rawValue)

        let bundle = try resolver.resolvePromptBundle(
            library: library,
            selection: selection,
            languageProcessing: .autoToEnglish,
            outputLanguage: .defaultSelection
        )

        expectEqual(bundle.typeId, MeetingType.general.rawValue)
        expectEqual(bundle.sourceKind, .builtInDefault)
        #expect(bundle.systemPrompt.contains("### CORE INSTRUCTIONS"))
    }

    @Test
    func resolvePromptBundle_forBuiltInOverride_usesOverrideSourceKindAndTypeIdentity() throws {
        var library = MeetingTypeLibrary.default
        let targetTypeID = MeetingType.general.rawValue
        let index = try #require(library.definitions.firstIndex(where: { $0.typeId == targetTypeID }))
        var definition = library.definitions[index]
        definition.promptComponents = PromptLibraryFixture.promptComponents(
            objective: "Override objective for leadership cadence.",
            summaryFocus: "Override focus for strategic alignment."
        )
        library.definitions[index] = definition

        let resolver = ResolvedPromptBundleResolver()
        let selection = MeetingTypeSelection(selectionMode: .manual, selectedTypeId: targetTypeID)

        let bundle = try resolver.resolvePromptBundle(
            library: library,
            selection: selection,
            languageProcessing: .autoToEnglish,
            outputLanguage: .defaultSelection
        )

        expectEqual(bundle.typeId, targetTypeID)
        expectEqual(bundle.sourceKind, .builtInOverride)
        #expect(bundle.systemPrompt.contains("Override objective for leadership cadence."))
    }

    @Test
    func resolvePromptBundle_autodetectMissingType_fallsBackToGeneral() throws {
        let library = MeetingTypeLibrary.default
        let resolver = ResolvedPromptBundleResolver()
        let selection = MeetingTypeSelection(selectionMode: .autodetect, selectedTypeId: MeetingType.autodetect.rawValue)

        let bundle = try resolver.resolvePromptBundle(
            library: library,
            selection: selection,
            languageProcessing: .autoToEnglish,
            outputLanguage: .defaultSelection,
            autodetectResolvedTypeID: "custom-missing"
        )

        expectEqual(bundle.typeId, MeetingType.general.rawValue)
        expectEqual(bundle.sourceKind, .builtInDefault)
    }

    @Test
    func resolvePromptBundle_whenSelectedTypeMissing_throwsUnavailableError() {
        let library = MeetingTypeLibrary.default
        let resolver = ResolvedPromptBundleResolver()
        let selection = MeetingTypeSelection(selectionMode: .manual, selectedTypeId: "missing-type")

        #expect(throws: ResolvedPromptBundleResolverError.self) {
            _ = try resolver.resolvePromptBundle(
                library: library,
                selection: selection,
                languageProcessing: .autoToEnglish,
                outputLanguage: .defaultSelection
            )
        }
    }
}
