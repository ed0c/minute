import Testing
@testable import Minute

@MainActor
struct SettingsWorkspaceContractTests {
    @Test
    func fallbackSelection_preservesMeetingTypesWhenAvailable() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        let resolved = SettingsCategoryCatalog.fallbackSelection(
            current: .meetingTypes,
            available: categories
        )

        #expect(resolved == .meetingTypes)
    }

    @Test
    func fallbackSelection_selectsFirstVisibleWhenMeetingTypesUnavailable() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: false).filter { $0.id != .meetingTypes }
        let resolved = SettingsCategoryCatalog.fallbackSelection(
            current: .meetingTypes,
            available: categories
        )

        #expect(resolved == categories.first?.id)
    }
}
