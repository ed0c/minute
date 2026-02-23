import MinuteCore

struct MeetingNotesOverlayState: Equatable {
    var selectedItem: MeetingNoteItem?
    var selectedTab: MeetingNotePreviewTab
    var isPresented: Bool

    init(
        selectedItem: MeetingNoteItem? = nil,
        selectedTab: MeetingNotePreviewTab = .summary,
        isPresented: Bool = false
    ) {
        self.selectedItem = selectedItem
        self.selectedTab = selectedTab
        self.isPresented = isPresented
    }

    mutating func select(_ item: MeetingNoteItem) {
        selectedItem = item
        selectedTab = .summary
        isPresented = true
    }

    mutating func selectTab(_ tab: MeetingNotePreviewTab) {
        guard selectedTab != tab else { return }
        selectedTab = tab
    }

    mutating func dismiss() {
        selectedItem = nil
        selectedTab = .summary
        isPresented = false
    }
}
