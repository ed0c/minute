import Testing
@testable import Minute

@MainActor
struct SettingsSectionReachabilityTests {
    @Test
    func meetingTypesCategory_isReachableFromCatalog() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        #expect(categories.contains(where: { $0.id == .meetingTypes }))
    }

    @Test
    func fallbackSelection_keepsMeetingTypesWhenAvailable() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        let selection = SettingsCategoryCatalog.fallbackSelection(
            current: .meetingTypes,
            available: categories
        )

        #expect(selection == .meetingTypes)
    }
}
