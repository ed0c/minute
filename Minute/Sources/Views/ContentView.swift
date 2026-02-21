//
//  ContentView.swift
//  Minute
//
//  Created by Robert Holst on 12/19/25.
//

import MinuteCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppNavigationModel
    @StateObject private var onboardingModel = OnboardingViewModel()

    var body: some View {
        Group {
            contentBody
        }
        .frame(minWidth: 1024, minHeight: 800)
        .background(MinuteTheme.windowBackground)
        .onAppear {
            onboardingModel.refreshAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .minuteMicActivityShowPipeline)) { _ in
            appState.showPipeline()
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if onboardingModel.isComplete {
            ZStack {
                PipelineContentView()
                    .opacity(appState.mainContent == .pipeline ? 1 : 0)
                    .allowsHitTesting(appState.mainContent == .pipeline)
                    .accessibilityHidden(appState.mainContent != .pipeline)

                MainSettingsView()
                    .opacity(appState.mainContent == .settings ? 1 : 0)
                    .allowsHitTesting(appState.mainContent == .settings)
                    .accessibilityHidden(appState.mainContent != .settings)
            }
            .animation(.easeInOut(duration: 0.15), value: appState.mainContent)
        } else {
            OnboardingView(model: onboardingModel)
        }
    }
}

#Preview(traits: .fixedLayout(width: 1024, height: 800)) {
    ContentView()
        .environmentObject(AppNavigationModel())
        .environmentObject(UpdaterViewModel.preview)
}
