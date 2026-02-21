import Foundation
@testable import Minute

@MainActor
enum SettingsWorkspaceTestSupport {
    static func makeNavigationModel(initial: AppNavigationModel.MainContent = .pipeline) -> AppNavigationModel {
        let model = AppNavigationModel()
        model.mainContent = initial
        return model
    }

    static func switchToSettings(_ model: AppNavigationModel) {
        model.showSettings()
    }

    static func switchToPipeline(_ model: AppNavigationModel) {
        model.showPipeline()
    }
}
