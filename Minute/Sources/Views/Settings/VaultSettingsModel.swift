import AppKit
import Combine
import Foundation
import MinuteCore

@MainActor
final class VaultSettingsModel: ObservableObject {
    @Published var vaultRootPathDisplay: String = "Not selected"
    @Published var meetingsRelativePath: String {
        didSet { UserDefaults.standard.set(meetingsRelativePath, forKey: AppConfiguration.Defaults.meetingsRelativePathKey) }
    }

    @Published var audioRelativePath: String {
        didSet { UserDefaults.standard.set(audioRelativePath, forKey: AppConfiguration.Defaults.audioRelativePathKey) }
    }

    @Published var transcriptsRelativePath: String {
        didSet {
            UserDefaults.standard.set(
                transcriptsRelativePath,
                forKey: AppConfiguration.Defaults.transcriptsRelativePathKey
            )
        }
    }

    @Published var lastVerificationMessage: String?
    @Published var lastErrorMessage: String?

    private let defaults = UserDefaults.standard
    private let bookmarkStore = UserDefaultsVaultBookmarkStore(key: AppConfiguration.Defaults.vaultRootBookmarkKey)

    init() {
        self.meetingsRelativePath = AppConfiguration.validatedRelativePath(
            defaults.string(forKey: AppConfiguration.Defaults.meetingsRelativePathKey),
            fallback: AppConfiguration.Defaults.defaultMeetingsRelativePath
        )
        self.audioRelativePath = AppConfiguration.validatedRelativePath(
            defaults.string(forKey: AppConfiguration.Defaults.audioRelativePathKey),
            fallback: AppConfiguration.Defaults.defaultAudioRelativePath
        )
        self.transcriptsRelativePath = AppConfiguration.validatedRelativePath(
            defaults.string(forKey: AppConfiguration.Defaults.transcriptsRelativePathKey),
            fallback: AppConfiguration.Defaults.defaultTranscriptsRelativePath
        )

        refreshVaultPathDisplay()
    }

    func chooseVaultRootFolder() async {
        lastErrorMessage = nil
        lastVerificationMessage = nil

        guard let url = await openFolderPanel() else {
            return
        }

        do {
            let bookmark = try VaultAccess.makeBookmarkData(forVaultRootURL: url)
            bookmarkStore.saveVaultRootBookmark(bookmark)
            defaults.set(url.path, forKey: AppConfiguration.Defaults.vaultRootPathDisplayKey)
            refreshVaultPathDisplay()
        } catch {
            lastErrorMessage = "Failed to save vault bookmark: \(error.localizedDescription)"
        }
    }

    func clearVaultSelection() {
        bookmarkStore.clearVaultRootBookmark()
        defaults.removeObject(forKey: AppConfiguration.Defaults.vaultRootPathDisplayKey)
        refreshVaultPathDisplay()
    }

    func verifyAccessAndCreateFolders() {
        lastErrorMessage = nil
        lastVerificationMessage = nil

        let access = VaultAccess(bookmarkStore: bookmarkStore)

        do {
            try access.withVaultAccess { vaultRootURL in
                let location = VaultLocation(
                    vaultRootURL: vaultRootURL,
                    meetingsRelativePath: meetingsRelativePath,
                    audioRelativePath: audioRelativePath,
                    transcriptsRelativePath: transcriptsRelativePath
                )

                try FileManager.default.createDirectory(at: location.meetingsFolderURL, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: location.audioFolderURL, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: location.transcriptsFolderURL, withIntermediateDirectories: true)
            }

            lastVerificationMessage = "Vault access OK. Folders are ready."
        } catch {
            lastErrorMessage = ErrorHandler.userMessage(for: error, fallback: "Failed to verify vault access.")
        }

        refreshVaultPathDisplay()
    }

    private func refreshVaultPathDisplay() {
        guard bookmarkStore.loadVaultRootBookmark() != nil else {
            setVaultPathDisplay("Not selected")
            return
        }

        let storedPath = defaults.string(forKey: AppConfiguration.Defaults.vaultRootPathDisplayKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let storedPath, !storedPath.isEmpty {
            setVaultPathDisplay(storedPath)
        } else {
            setVaultPathDisplay("Vault selected")
        }
    }

    private func setVaultPathDisplay(_ value: String) {
        guard vaultRootPathDisplay != value else { return }
        vaultRootPathDisplay = value
    }

    private func openFolderPanel() async -> URL? {
        await withCheckedContinuation { continuation in
            let panel = NSOpenPanel()
            panel.title = "Select your Obsidian vault root folder"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = false

            panel.begin { response in
                guard response == .OK, let url = panel.url else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: url)
            }
        }
    }
}
