import Foundation
import Testing
@testable import MinuteCore

struct VaultPathNormalizerTests {
    @Test
    func normalizedRelativeComponents_stripsUnsafeTokens() {
        let components = VaultPathNormalizer.normalizedRelativeComponents(" /Meetings//./2026/../02/ ")
        #expect(components == ["Meetings", "2026", "02"])
    }

    @Test
    func directoryURL_buildsPathFromNormalizedComponents() {
        let root = URL(fileURLWithPath: "/tmp/Vault", isDirectory: true)
        let url = VaultPathNormalizer.directoryURL(from: root, relativePath: "Meetings/_transcripts")

        #expect(url.path == "/tmp/Vault/Meetings/_transcripts")
    }

    @Test
    func relativePath_returnsPathInsideVaultRoot() {
        let root = URL(fileURLWithPath: "/tmp/Vault", isDirectory: true)
        let fileURL = URL(fileURLWithPath: "/tmp/Vault/Meetings/2026/02/Note.md")

        let relative = VaultPathNormalizer.relativePath(from: root, to: fileURL)
        #expect(relative == "Meetings/2026/02/Note.md")
    }
}
