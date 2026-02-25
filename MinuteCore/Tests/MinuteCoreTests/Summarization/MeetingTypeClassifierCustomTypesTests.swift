import Testing
@testable import MinuteCore

struct MeetingTypeClassifierCustomTypesTests {
    @Test
    func prompt_withCustomCandidates_includesCustomLabelsAndSignals() {
        let candidates: [MeetingTypeClassifierCandidate] = [
            MeetingTypeClassifierCandidate(
                typeId: MeetingType.general.rawValue,
                label: "General",
                strongSignals: ["mixed agenda"]
            ),
            MeetingTypeClassifierCandidate(
                typeId: "custom-customer-discovery",
                label: "Customer Discovery",
                strongSignals: ["user interviews", "customer pain points"]
            ),
        ]

        let prompt = MeetingTypeClassifier.prompt(
            for: "Transcript snippet",
            candidates: candidates,
            fallbackLabel: "General"
        )

        #expect(prompt.contains("Customer Discovery"))
        #expect(prompt.contains("user interviews"))
        #expect(prompt.contains("customer pain points"))
    }

    @Test
    func parseCustomResponse_returnsMatchingCustomTypeID() {
        let candidates: [MeetingTypeClassifierCandidate] = [
            MeetingTypeClassifierCandidate(typeId: MeetingType.general.rawValue, label: "General", strongSignals: []),
            MeetingTypeClassifierCandidate(
                typeId: "custom-customer-discovery",
                label: "Customer Discovery",
                strongSignals: ["interview insights"]
            ),
        ]

        let resolved = MeetingTypeClassifier.parseResponse(
            "customer discovery",
            candidates: candidates,
            fallbackTypeID: MeetingType.general.rawValue
        )

        expectEqual(resolved, "custom-customer-discovery")
    }

    @Test
    func parseCustomResponse_unknownLabel_returnsFallbackTypeID() {
        let candidates: [MeetingTypeClassifierCandidate] = [
            MeetingTypeClassifierCandidate(typeId: MeetingType.general.rawValue, label: "General", strongSignals: []),
            MeetingTypeClassifierCandidate(
                typeId: "custom-customer-discovery",
                label: "Customer Discovery",
                strongSignals: ["interview insights"]
            ),
        ]

        let resolved = MeetingTypeClassifier.parseResponse(
            "Something Else",
            candidates: candidates,
            fallbackTypeID: MeetingType.general.rawValue
        )

        expectEqual(resolved, MeetingType.general.rawValue)
    }
}
