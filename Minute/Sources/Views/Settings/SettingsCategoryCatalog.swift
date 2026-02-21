import SwiftUI

struct SettingsCategoryDefinition: Identifiable, Hashable {
    enum ID: String, CaseIterable, Hashable {
        case general
        case storage
        case speakers
        case privacy
        case ai
        case updates
    }

    var id: ID
    var title: String
    var iconName: String
    var sortOrder: Int
    var description: String
    var isVisible: Bool

    var accessibilityLabel: String {
        "\(title) settings category"
    }
}

enum SettingsCategoryCatalog {
    // When adding a new category:
    // 1) Add a new `ID` case.
    // 2) Insert a `SettingsCategoryDefinition` with a unique `sortOrder`.
    // 3) Keep titles task-oriented and stable so users build navigation memory.
    // 4) Update `MainSettingsView` switch rendering and category coverage tests.
    static func categories(updatesEnabled: Bool) -> [SettingsCategoryDefinition] {
        var definitions: [SettingsCategoryDefinition] = [
            SettingsCategoryDefinition(
                id: .general,
                title: "General",
                iconName: "slider.horizontal.3",
                sortOrder: 10,
                description: "Default behavior, language, and capture options.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .storage,
                title: "Vault",
                iconName: "externaldrive",
                sortOrder: 20,
                description: "Vault root and folders for notes, audio, and transcripts.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .speakers,
                title: "Speakers",
                iconName: "person.2",
                sortOrder: 30,
                description: "Known speaker suggestions and profile management.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .privacy,
                title: "Privacy & Permissions",
                iconName: "hand.raised",
                sortOrder: 40,
                description: "Microphone and screen recording permissions.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .ai,
                title: "AI & Models",
                iconName: "sparkles",
                sortOrder: 50,
                description: "Transcription, summarization, and local model status.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .updates,
                title: "Updates",
                iconName: "arrow.down.circle",
                sortOrder: 60,
                description: "Application update checks and channels.",
                isVisible: updatesEnabled
            ),
        ]

        definitions.sort { $0.sortOrder < $1.sortOrder }
        return definitions.filter(\.isVisible)
    }

    static func fallbackSelection(
        current: SettingsCategoryDefinition.ID?,
        available: [SettingsCategoryDefinition]
    ) -> SettingsCategoryDefinition.ID? {
        if let current,
           available.contains(where: { $0.id == current }) {
            return current
        }
        return available.first?.id
    }
}
