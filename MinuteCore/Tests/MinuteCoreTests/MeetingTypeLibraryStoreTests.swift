import Foundation
import Testing
@testable import MinuteCore

struct MeetingTypeLibraryStoreTests {
    @Test
    func load_whenUnset_returnsDefaultLibrary() {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)

        let loaded = store.load()

        expectEqual(loaded.defaultTypeId, MeetingTypeLibrary.default.defaultTypeId)
        #expect(!loaded.definitions.isEmpty)
    }

    @Test
    func saveThenLoad_roundTripsValidatedLibrary() throws {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)
        let custom = PromptLibraryFixture.customDefinition(
            typeId: "custom-customer-sync",
            displayName: "Customer Sync"
        )
        let library = PromptLibraryFixture.defaultLibraryWithCustom(custom: custom)

        try store.saveValidated(library)
        let loaded = store.load()

        let loadedCustom = loaded.definition(for: custom.typeId)
        #expect(loadedCustom != nil)
        expectEqual(loadedCustom?.displayName, "Customer Sync")
    }

    @Test
    func load_invalidPersistedPayload_returnsDefaultLibrary() {
        let defaults = makeDefaults()
        defaults.set(Data("not-json".utf8), forKey: "library")

        let store = makeStore(defaults: defaults)
        let loaded = store.load()

        expectEqual(loaded.defaultTypeId, MeetingTypeLibrary.default.defaultTypeId)
        expectEqual(loaded.definitions.map(\.typeId), MeetingTypeLibrary.default.definitions.map(\.typeId))
    }

    @Test
    func load_validationFailure_returnsDefaultLibrary() throws {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)

        let duplicateA = PromptLibraryFixture.customDefinition(
            typeId: "custom-a",
            displayName: "Sales Review"
        )
        let duplicateB = PromptLibraryFixture.customDefinition(
            typeId: "custom-b",
            displayName: "sales review"
        )
        let invalid = PromptLibraryFixture.library(definitions: [duplicateA, duplicateB], defaultTypeId: duplicateA.typeId)

        let encoded = try JSONEncoder().encode(invalid)
        defaults.set(encoded, forKey: "library")
        let loaded = store.load()

        expectEqual(loaded.defaultTypeId, MeetingTypeLibrary.default.defaultTypeId)
        expectEqual(loaded.definitions.map(\.typeId), MeetingTypeLibrary.default.definitions.map(\.typeId))
    }

    @Test
    func clear_removesPersistedLibrary() throws {
        let defaults = makeDefaults()
        let store = makeStore(defaults: defaults)
        let custom = PromptLibraryFixture.customDefinition(typeId: "custom-cleared")
        let library = PromptLibraryFixture.defaultLibraryWithCustom(custom: custom)
        try store.saveValidated(library)

        store.clear()
        let loaded = store.load()

        #expect(loaded.definition(for: custom.typeId) == nil)
        expectEqual(loaded.defaultTypeId, MeetingTypeLibrary.default.defaultTypeId)
        expectEqual(loaded.definitions.map(\.typeId), MeetingTypeLibrary.default.definitions.map(\.typeId))
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "MeetingTypeLibraryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func makeStore(defaults: UserDefaults) -> MeetingTypeLibraryStore {
        MeetingTypeLibraryStore(
            defaults: defaults,
            libraryKey: "library"
        )
    }
}
