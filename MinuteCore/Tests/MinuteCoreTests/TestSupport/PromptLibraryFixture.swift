import Foundation
@testable import MinuteCore

enum PromptLibraryFixture {
    static func promptComponents(
        objective: String = "Capture meeting outcomes accurately.",
        summaryFocus: String = "Prioritize decisions and action items.",
        decisionRules: String = "",
        actionItemRules: String = "",
        openQuestionRules: String = "",
        keyPointRules: String = "",
        noiseFilterRules: String = "",
        additionalGuidance: String = "",
        version: Int = 1
    ) -> PromptComponentSet {
        PromptComponentSet(
            objective: objective,
            summaryFocus: summaryFocus,
            decisionRules: decisionRules,
            actionItemRules: actionItemRules,
            openQuestionRules: openQuestionRules,
            keyPointRules: keyPointRules,
            noiseFilterRules: noiseFilterRules,
            additionalGuidance: additionalGuidance,
            version: version
        )
    }

    static func classifierProfile(
        label: String = "Customer Discovery",
        strongSignals: [String] = ["customer interviews", "feedback synthesis"],
        counterSignals: [String] = [],
        positiveExamples: [String] = [],
        negativeExamples: [String] = []
    ) -> ClassifierProfile {
        ClassifierProfile(
            label: label,
            strongSignals: strongSignals,
            counterSignals: counterSignals,
            positiveExamples: positiveExamples,
            negativeExamples: negativeExamples
        )
    }

    static func customDefinition(
        typeId: String = "custom-customer-discovery",
        displayName: String = "Customer Discovery",
        autodetectEligible: Bool = false,
        promptComponents: PromptComponentSet = promptComponents(),
        classifierProfile: ClassifierProfile? = nil,
        status: MeetingTypeDefinitionStatus = .active
    ) -> MeetingTypeDefinition {
        MeetingTypeDefinition(
            typeId: typeId,
            displayName: displayName,
            source: .custom,
            isDeletable: true,
            isEditableName: true,
            autodetectEligible: autodetectEligible,
            promptComponents: promptComponents,
            classifierProfile: classifierProfile,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            status: status
        )
    }

    static func builtInDefinition(
        meetingType: MeetingType = .general
    ) -> MeetingTypeDefinition {
        MeetingTypeLibrary.default.definition(for: meetingType.rawValue)!
    }

    static func library(
        definitions: [MeetingTypeDefinition],
        defaultTypeId: String = MeetingType.autodetect.rawValue,
        libraryVersion: Int = 1
    ) -> MeetingTypeLibrary {
        MeetingTypeLibrary(
            definitions: definitions,
            defaultTypeId: defaultTypeId,
            libraryVersion: libraryVersion,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func defaultLibraryWithCustom(
        custom: MeetingTypeDefinition = customDefinition()
    ) -> MeetingTypeLibrary {
        var definitions = MeetingTypeLibrary.default.definitions
        definitions.append(custom)
        return library(definitions: definitions)
    }
}
