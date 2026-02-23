import Foundation
@testable import MinuteCore

enum RefactorParityTestSupport {
    static func makeTemporaryDirectory(prefix: String = "minute-refactor-parity") throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func makeVaultAccess(vaultRootURL: URL) throws -> VaultAccess {
        let bookmark = try VaultAccess.makeBookmarkData(forVaultRootURL: vaultRootURL)
        return VaultAccess(bookmarkStore: RefactorParityBookmarkStore(bookmark: bookmark))
    }

    static func makePipelineContext(
        audioTempURL: URL,
        workingDirectoryURL: URL,
        startedAt: Date = Date(timeIntervalSince1970: 1_708_000_000),
        stoppedAt: Date = Date(timeIntervalSince1970: 1_708_000_180),
        saveAudio: Bool = true,
        saveTranscript: Bool = true
    ) -> PipelineContext {
        PipelineContext(
            vaultFolders: MeetingFileContract.VaultFolders(),
            audioTempURL: audioTempURL,
            audioDurationSeconds: stoppedAt.timeIntervalSince(startedAt),
            startedAt: startedAt,
            stoppedAt: stoppedAt,
            workingDirectoryURL: workingDirectoryURL,
            saveAudio: saveAudio,
            saveTranscript: saveTranscript
        )
    }
}

final class RefactorParityBookmarkStore: VaultBookmarkStoring {
    private var bookmark: Data?

    init(bookmark: Data?) {
        self.bookmark = bookmark
    }

    func loadVaultRootBookmark() -> Data? {
        bookmark
    }

    func saveVaultRootBookmark(_ bookmark: Data) {
        self.bookmark = bookmark
    }

    func clearVaultRootBookmark() {
        bookmark = nil
    }
}
