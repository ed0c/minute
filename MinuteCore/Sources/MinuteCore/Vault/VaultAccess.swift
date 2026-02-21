import Foundation

public struct VaultAccess {
    private final class ResolutionContinuationBox: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<URL, Error>?

        init(_ continuation: CheckedContinuation<URL, Error>) {
            self.continuation = continuation
        }

        func resume(with result: Result<URL, Error>) {
            lock.lock()
            guard let continuation else {
                lock.unlock()
                return
            }
            self.continuation = nil
            lock.unlock()
            continuation.resume(with: result)
        }
    }

    private let bookmarkStore: any VaultBookmarkStoring

    public init(bookmarkStore: some VaultBookmarkStoring) {
        self.bookmarkStore = bookmarkStore
    }

    public func resolveVaultRootURL() throws -> URL {
        guard let bookmark = bookmarkStore.loadVaultRootBookmark() else {
            throw MinuteError.vaultUnavailable
        }

        return try Self.resolveVaultRootURL(fromBookmark: bookmark, timeout: .seconds(2))
    }

    public func resolveVaultRootURL(timeout: Duration) async throws -> URL {
        guard let bookmark = bookmarkStore.loadVaultRootBookmark() else {
            throw MinuteError.vaultUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let continuationBox = ResolutionContinuationBox(continuation)

            DispatchQueue.global(qos: .userInitiated).async {
                continuationBox.resume(with: Result {
                    try Self.resolveVaultRootURL(fromBookmark: bookmark)
                })
            }

            Task.detached(priority: .userInitiated) {
                try? await Task.sleep(for: timeout)
                continuationBox.resume(with: .failure(MinuteError.vaultUnavailable))
            }
        }
    }

    private static func resolveVaultRootURL(fromBookmark bookmark: Data, timeout: DispatchTimeInterval) throws -> URL {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: Result<URL, Error>?

        DispatchQueue.global(qos: .userInitiated).async {
            let resolved = Result {
                try Self.resolveVaultRootURL(fromBookmark: bookmark)
            }
            lock.lock()
            result = resolved
            lock.unlock()
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw MinuteError.vaultUnavailable
        }

        lock.lock()
        defer { lock.unlock() }
        guard let result else {
            throw MinuteError.vaultUnavailable
        }
        return try result.get()
    }

    private static func resolveVaultRootURL(fromBookmark bookmark: Data) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            throw MinuteError.vaultUnavailable
        }

        return url
    }

    public func withVaultAccess<T>(_ work: (URL) throws -> T) throws -> T {
        let vaultRootURL = try resolveVaultRootURL()

        guard vaultRootURL.startAccessingSecurityScopedResource() else {
            throw MinuteError.vaultUnavailable
        }
        defer { vaultRootURL.stopAccessingSecurityScopedResource() }

        return try work(vaultRootURL)
    }

    public static func makeBookmarkData(forVaultRootURL url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}
