import Foundation
import Testing
@testable import MinuteCore

struct BuiltInPromptOverrideStoreTests {
    @Test
    func saveBuiltInOverride_persistsOverrideAndMarksOverridden() throws {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")
        let targetTypeID = MeetingType.general.rawValue
        let customComponents = PromptLibraryFixture.promptComponents(
            objective: "Summarize leadership updates with emphasis on outcomes.",
            summaryFocus: "Prioritize strategic decisions and risks."
        )

        let saved = try store.saveBuiltInOverride(
            typeID: targetTypeID,
            promptComponents: customComponents
        )

        #expect(saved.isOverridden)
        expectEqual(saved.typeId, targetTypeID)
        expectEqual(saved.overrideComponents, customComponents)

        let reloadedOverride = store.builtInOverride(for: targetTypeID)
        #expect(reloadedOverride != nil)
        #expect(reloadedOverride?.isOverridden == true)
        expectEqual(reloadedOverride?.overrideComponents, customComponents)
    }

    @Test
    func restoreBuiltInDefault_clearsOverrideAndResetsPromptComponents() throws {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")
        let targetTypeID = MeetingType.standup.rawValue
        let baseline = MeetingTypeLibrary.default.definition(for: targetTypeID)?.promptComponents

        _ = try store.saveBuiltInOverride(
            typeID: targetTypeID,
            promptComponents: PromptLibraryFixture.promptComponents(
                objective: "Temporary objective override.",
                summaryFocus: "Temporary focus override."
            )
        )
        let restored = try store.restoreBuiltInDefault(typeID: targetTypeID)

        #expect(restored.isOverridden == false)
        expectEqual(restored.overrideComponents, baseline)
        expectEqual(store.builtInOverride(for: targetTypeID)?.isOverridden, false)
        expectEqual(
            store.load().definition(for: targetTypeID)?.promptComponents,
            baseline
        )
    }

    @Test
    func saveBuiltInOverride_autodetect_isRejected() {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "library")
        let targetTypeID = MeetingType.autodetect.rawValue

        do {
            _ = try store.saveBuiltInOverride(
                typeID: targetTypeID,
                promptComponents: PromptLibraryFixture.promptComponents(
                    objective: "Should not apply.",
                    summaryFocus: "Should not apply."
                )
            )
            Issue.record("Expected autodetect override to be rejected")
        } catch let error as MeetingTypeLibraryStoreError {
            #expect(error == .typeIsNotEditable(targetTypeID))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "BuiltInPromptOverrideStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
