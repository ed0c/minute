import SwiftUI

/// Deprecated compatibility wrapper.
/// Settings now render as a full-window workspace in `ContentView`.
struct SettingsOverlayView: View {
    var body: some View {
        MainSettingsView()
    }
}

#Preview {
    SettingsOverlayView()
        .environmentObject(AppNavigationModel())
        .environmentObject(UpdaterViewModel.preview)
}
