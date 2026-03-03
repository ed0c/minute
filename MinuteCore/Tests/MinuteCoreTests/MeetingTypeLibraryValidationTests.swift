import Foundation
import Testing
@testable import MinuteCore

struct MeetingTypeLibraryValidationTests {
    @Test
    func promptComponents_requiresObjectiveAndSummaryFocus() {
        let missingObjective = PromptLibraryFixture.promptComponents(
            objective: "   ",
            summaryFocus: "Capture outcomes."
        )

        #expect(throws: MeetingTypeLibraryValidationError.self) {
            try missingObjective.validated()
        }

        let missingSummaryFocus = PromptLibraryFixture.promptComponents(
            objective: "Summarize accurately.",
            summaryFocus: "\n"
        )

        #expect(throws: MeetingTypeLibraryValidationError.self) {
            try missingSummaryFocus.validated()
        }
    }

    @Test
    func meetingTypeDefinition_autodetectEligibleRequiresClassifierSignals() {
        let invalidDefinition = PromptLibraryFixture.customDefinition(
            autodetectEligible: true,
            classifierProfile: nil
        )

        #expect(throws: MeetingTypeLibraryValidationError.self) {
            try invalidDefinition.validated()
        }

        let noSignalsDefinition = PromptLibraryFixture.customDefinition(
            autodetectEligible: true,
            classifierProfile: PromptLibraryFixture.classifierProfile(
                label: "Customer Discovery",
                strongSignals: []
            )
        )

        #expect(throws: MeetingTypeLibraryValidationError.self) {
            try noSignalsDefinition.validated()
        }
    }

    @Test
    func meetingTypeLibrary_rejectsCaseInsensitiveDuplicateDisplayNames() {
        let customA = PromptLibraryFixture.customDefinition(
            typeId: "custom-discovery-1",
            displayName: "Discovery Review"
        )
        let customB = PromptLibraryFixture.customDefinition(
            typeId: "custom-discovery-2",
            displayName: "discovery review"
        )
        let library = PromptLibraryFixture.library(definitions: [customA, customB], defaultTypeId: customA.typeId)

        #expect(throws: MeetingTypeLibraryValidationError.self) {
            try library.validated()
        }
    }

    @Test
    func meetingTypeLibrary_normalizesDefaultsAndVersion() throws {
        let custom = PromptLibraryFixture.customDefinition(typeId: "custom-1")
        let library = PromptLibraryFixture.library(
            definitions: [custom],
            defaultTypeId: "missing-type-id",
            libraryVersion: 0
        )

        let validated = try library.validated()

        expectEqual(validated.defaultTypeId, custom.typeId)
        expectEqual(validated.libraryVersion, 1)
    }
}
