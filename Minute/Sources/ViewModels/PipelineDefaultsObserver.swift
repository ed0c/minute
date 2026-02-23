import Foundation
import MinuteCore

struct PipelineDefaultsObserver {
    struct Snapshot: Equatable {
        var vaultRootBookmark: Data?
        var vaultRootPathDisplay: String?
        var outputLanguageRawValue: String?
        var transcriptionBackendID: String?
        var vocabularySettings: GlobalVocabularyBoostingSettings
    }

    struct ChangedDomains: Equatable {
        var requiresFullRefresh: Bool
        var vaultStatusChanged: Bool
        var outputLanguageChanged: Bool
        var transcriptionBackendChanged: Bool
        var vocabularySettingsChanged: Bool

        var hasChanges: Bool {
            requiresFullRefresh
                || vaultStatusChanged
                || outputLanguageChanged
                || transcriptionBackendChanged
                || vocabularySettingsChanged
        }
    }

    static func makeSnapshot(
        defaults: UserDefaults,
        transcriptionBackendID: String?,
        vocabularySettings: GlobalVocabularyBoostingSettings
    ) -> Snapshot {
        Snapshot(
            vaultRootBookmark: defaults.data(forKey: AppConfiguration.Defaults.vaultRootBookmarkKey),
            vaultRootPathDisplay: defaults.string(forKey: AppConfiguration.Defaults.vaultRootPathDisplayKey),
            outputLanguageRawValue: defaults.string(forKey: AppConfiguration.Defaults.outputLanguageKey),
            transcriptionBackendID: transcriptionBackendID,
            vocabularySettings: vocabularySettings
        )
    }

    static func changedDomains(previous: Snapshot?, current: Snapshot) -> ChangedDomains {
        guard let previous else {
            return ChangedDomains(
                requiresFullRefresh: true,
                vaultStatusChanged: true,
                outputLanguageChanged: true,
                transcriptionBackendChanged: true,
                vocabularySettingsChanged: true
            )
        }

        return ChangedDomains(
            requiresFullRefresh: false,
            vaultStatusChanged:
                previous.vaultRootBookmark != current.vaultRootBookmark
                || previous.vaultRootPathDisplay != current.vaultRootPathDisplay,
            outputLanguageChanged: previous.outputLanguageRawValue != current.outputLanguageRawValue,
            transcriptionBackendChanged: previous.transcriptionBackendID != current.transcriptionBackendID,
            vocabularySettingsChanged: previous.vocabularySettings != current.vocabularySettings
        )
    }
}
