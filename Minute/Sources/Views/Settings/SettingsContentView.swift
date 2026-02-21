import SwiftUI

/// Legacy compatibility wrapper retained for internal preview references.
/// The canonical settings detail composition lives in `MainSettingsView`.
struct SettingsContentView: View {
    @ObservedObject var model: VaultSettingsModel

    var body: some View {
        Form {
            VaultConfigurationView(model: model, style: .settings)
        }
    }
}
