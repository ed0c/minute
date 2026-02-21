import Foundation

public struct VaultAccess {
    private final class ResolutionContinuationBox: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<URL, Error>?

        init(_ continuation: CheckedContinuation<URL, Error>? = nil) {
            self.continuation = continuation
        }

        func set(_ continuation: CheckedContinuation<URL, Error>) {
            lock.lock()
            self.continuation = continuation
            lock.unlock()
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

    private final class TimeoutTaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var task: Task<Void, Never>?

        func set(_ task: Task<Void, Never>) {
            lock.lock()
            self.task = task
            lock.unlock()
        }

        func cancel() {
            lock.lock()
            let task = self.task
            self.task = nil
            lock.unlock()
            task?.cancel()
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

        return try Self.resolveVaultRootURL(fromBookmark: bookmark)
    }

    public func resolveVaultRootURL(timeout: Duration) async throws -> URL {
        guard let bookmark = bookmarkStore.loadVaultRootBookmark() else {
            throw MinuteError.vaultUnavailable
        }

        let continuationBox = ResolutionContinuationBox()
        let timeoutTaskBox = TimeoutTaskBox()

        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()

            return try await withCheckedThrowingContinuation { continuation in
                continuationBox.set(continuation)

                let timeoutTask = Task.detached(priority: .userInitiated) {
                    try? await Task.sleep(for: timeout)
                    continuationBox.resume(with: .failure(MinuteError.vaultUnavailable))
                }
                timeoutTaskBox.set(timeoutTask)

                DispatchQueue.global(qos: .userInitiated).async {
                    continuationBox.resume(with: Result {
                        try Self.resolveVaultRootURL(fromBookmark: bookmark)
                    })
                    timeoutTaskBox.cancel()
                }
            }
        }, onCancel: {
            timeoutTaskBox.cancel()
            continuationBox.resume(with: .failure(CancellationError()))
        })
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
