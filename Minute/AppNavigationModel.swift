import Combine
import Foundation

@MainActor
final class AppNavigationModel: ObservableObject {
    enum MainContent: String {
        case pipeline
        case settings
    }

    @Published var mainContent: MainContent = .pipeline
    @Published private(set) var previousMainContent: MainContent?
    @Published private(set) var changedAt: Date = Date()

    struct WorkspaceStateSnapshot: Equatable {
        var activeWorkspace: MainContent
        var previousWorkspace: MainContent?
        var windowMode: String
        var noAdditionalWindow: Bool
    }

    func showSettings() {
        setActiveWorkspace(.settings)
    }

    func showPipeline() {
        setActiveWorkspace(.pipeline)
    }

    func setActiveWorkspace(_ target: MainContent) {
        guard mainContent != target else { return }
        previousMainContent = mainContent
        mainContent = target
        changedAt = Date()
    }

    func snapshot() -> WorkspaceStateSnapshot {
        WorkspaceStateSnapshot(
            activeWorkspace: mainContent,
            previousWorkspace: previousMainContent,
            windowMode: "single_window",
            noAdditionalWindow: true
        )
    }
}
