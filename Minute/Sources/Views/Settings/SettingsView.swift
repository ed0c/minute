import SwiftUI

/// Legacy preview-only wrapper kept for compatibility with older previews.
/// Primary settings rendering now happens inside the main window via `ContentView`.
struct SettingsView: View {
    @StateObject private var appState = AppNavigationModel()
    @StateObject private var updaterViewModel = UpdaterViewModel.preview

    var body: some View {
        MainSettingsView()
            .environmentObject(appState)
            .environmentObject(updaterViewModel)
            .frame(width: 900, height: 620)
    }
}

#Preview {
    SettingsView()
}
