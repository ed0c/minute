import Foundation
import Testing
@testable import Minute
@testable import MinuteCore

@MainActor
struct MeetingTypesSettingsViewModelTests {
    @Test
    func createCustomType_workflowAddsTypeToLibraryAndSelectsIt() {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "meetingTypeLibrary")
        let model = MeetingTypesSettingsViewModel(store: store)

        model.startCreateCustomType()
        model.draftDisplayName = "Customer Discovery"
        model.draftObjective = "Summarize customer interviews."
        model.draftSummaryFocus = "Highlight learnings, risks, and owners."
        model.saveDraft()

        #expect(model.errorMessage == nil)
        #expect(model.meetingTypes.contains(where: { $0.displayName == "Customer Discovery" }))
        #expect(model.selectedDefinition?.source == .custom)
    }

    @Test
    func updateCustomType_workflowPersistsDraftChanges() {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "meetingTypeLibrary")
        let model = MeetingTypesSettingsViewModel(store: store)

        model.startCreateCustomType()
        model.draftDisplayName = "Design Ops"
        model.draftObjective = "Summarize design operations sync."
        model.draftSummaryFocus = "Capture blockers and ownership."
        model.saveDraft()

        guard let customTypeID = model.selectedTypeID else {
            Issue.record("Expected newly created custom type selection")
            return
        }

        model.selectType(typeID: customTypeID)
        model.draftDisplayName = "Design Operations"
        model.draftObjective = "Summarize design operations meetings."
        model.draftSummaryFocus = "Capture blockers, decisions, and assigned work."
        model.saveDraft()

        #expect(model.errorMessage == nil)
        #expect(model.selectedDefinition?.displayName == "Design Operations")
        #expect(
            model.selectedDefinition?.promptComponents.summaryFocus
                == "Capture blockers, decisions, and assigned work."
        )
    }

    @Test
    func builtInOverride_andRestoreDefault_updatesSourceStatus() {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "meetingTypeLibrary")
        let model = MeetingTypesSettingsViewModel(store: store)
        let builtInTypeID = MeetingType.general.rawValue

        model.selectType(typeID: builtInTypeID)
        model.draftObjective = "Custom general objective."
        model.draftSummaryFocus = "Custom general focus."
        model.saveDraft()

        #expect(model.errorMessage == nil)
        #expect(model.selectedDefinition?.source == .builtIn)
        #expect(model.isSelectedBuiltInOverridden)

        model.restoreBuiltInDefault()

        #expect(model.errorMessage == nil)
        #expect(model.isSelectedBuiltInOverridden == false)
        #expect(model.selectedDefinition?.source == .builtIn)
    }

    @Test
    func editableMeetingTypes_excludesAutodetect() {
        let defaults = makeDefaults()
        let store = MeetingTypeLibraryStore(defaults: defaults, libraryKey: "meetingTypeLibrary")
        let model = MeetingTypesSettingsViewModel(store: store)

        #expect(model.meetingTypes.contains(where: { $0.typeId == MeetingType.autodetect.rawValue }) == false)
        #expect(model.selectedTypeID != MeetingType.autodetect.rawValue)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "MeetingTypesSettingsViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
