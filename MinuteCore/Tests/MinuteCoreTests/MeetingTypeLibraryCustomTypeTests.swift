import Foundation
import Testing
@testable import MinuteCore

struct MeetingTypeLibraryCustomTypeTests {
    @Test
    func createCustomType_persistsAndListsInActiveDefinitions() throws {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")

        let created = try store.createCustomType(
            displayName: "Customer Discovery",
            promptComponents: PromptLibraryFixture.promptComponents(
                objective: "Capture discovery insights.",
                summaryFocus: "Highlight customer pain points and next steps."
            )
        )

        #expect(created.source == .custom)
        #expect(created.typeId.hasPrefix("custom-"))

        let reloaded = store.load()
        let loaded = reloaded.definition(for: created.typeId)
        #expect(loaded != nil)
        expectEqual(loaded?.displayName, "Customer Discovery")
    }

    @Test
    func updateCustomType_updatesNameAndPromptComponents() throws {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")
        let created = try store.createCustomType(
            displayName: "Weekly Operations",
            promptComponents: PromptLibraryFixture.promptComponents(
                objective: "Summarize operations meetings.",
                summaryFocus: "Capture blockers and owners."
            )
        )

        let updated = try store.updateCustomType(
            typeID: created.typeId,
            displayName: "Operations Sync",
            promptComponents: PromptLibraryFixture.promptComponents(
                objective: "Summarize operations sync meetings.",
                summaryFocus: "Capture priorities and committed owners."
            )
        )

        expectEqual(updated.displayName, "Operations Sync")
        expectEqual(updated.promptComponents.objective, "Summarize operations sync meetings.")
        expectEqual(updated.promptComponents.summaryFocus, "Capture priorities and committed owners.")
    }

    @Test
    func createCustomType_rejectsDuplicateCaseInsensitiveNames() throws {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")
        _ = try store.createCustomType(
            displayName: "Design Critique",
            promptComponents: PromptLibraryFixture.promptComponents()
        )

        #expect(throws: MeetingTypeLibraryStoreError.self) {
            _ = try store.createCustomType(
                displayName: "design critique",
                promptComponents: PromptLibraryFixture.promptComponents()
            )
        }
    }

    @Test
    func updateCustomType_rejectsDuplicateNameDuringRename() throws {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")
        let alpha = try store.createCustomType(
            displayName: "Alpha Review",
            promptComponents: PromptLibraryFixture.promptComponents()
        )
        _ = try store.createCustomType(
            displayName: "Beta Review",
            promptComponents: PromptLibraryFixture.promptComponents()
        )

        #expect(throws: MeetingTypeLibraryStoreError.self) {
            _ = try store.updateCustomType(typeID: alpha.typeId, displayName: "beta review")
        }
    }

    @Test
    func deleteCustomType_marksTypeDeletedAndRemovesFromActiveList() throws {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")
        let custom = try store.createCustomType(
            displayName: "Quarterly Retro",
            promptComponents: PromptLibraryFixture.promptComponents()
        )

        let deleted = try store.deleteCustomType(typeID: custom.typeId)

        expectEqual(deleted.status, .deleted)
        #expect(store.listActiveDefinitions().contains(where: { $0.typeId == custom.typeId }) == false)
    }

    @Test
    func deleteCustomType_rejectsBuiltInIDs() {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")

        #expect(throws: MeetingTypeLibraryStoreError.self) {
            _ = try store.deleteCustomType(typeID: MeetingType.general.rawValue)
        }
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "MeetingTypeLibraryCustomTypeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
