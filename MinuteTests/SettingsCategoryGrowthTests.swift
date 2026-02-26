import Testing
@testable import Minute

@MainActor
struct SettingsCategoryGrowthTests {
    @Test
    func categoryIDsRemainUniqueWithMeetingTypesAdded() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        let uniqueIDs = Set(categories.map(\.id))

        #expect(uniqueIDs.count == categories.count)
    }

    @Test
    func categorySortOrdersRemainUniqueWithMeetingTypesAdded() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        let uniqueSortOrders = Set(categories.map(\.sortOrder))

        #expect(uniqueSortOrders.count == categories.count)
        #expect(categories.contains(where: { $0.id == .meetingTypes }))
    }
}
