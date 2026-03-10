import Foundation

public actor DefaultSummarizationCheckpointStore: SummarizationCheckpointStoring {
    private let fileManager: FileManager
    private let baseDirectoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        if let baseDirectoryURL {
            self.baseDirectoryURL = baseDirectoryURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.baseDirectoryURL = appSupport
                .appendingPathComponent("Minute", isDirectory: true)
                .appendingPathComponent("Recovery", isDirectory: true)
                .appendingPathComponent("Summarization", isDirectory: true)
        }
    }

    public func load(meetingID: String) async throws -> SummarizationRunState? {
        let url = checkpointURL(meetingID: meetingID)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(SummarizationRunState.self, from: data)
    }

    public func save(_ state: SummarizationRunState, for meetingID: String) async throws {
        try ensureBaseDirectory()
        let url = checkpointURL(meetingID: meetingID)
        let data = try encoder.encode(state)
        try data.write(to: url, options: [.atomic])
    }

    public func clear(meetingID: String) async {
        let url = checkpointURL(meetingID: meetingID)
        try? fileManager.removeItem(at: url)
    }

    private func ensureBaseDirectory() throws {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: baseDirectoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return
        }
        try fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
    }

    private func checkpointURL(meetingID: String) -> URL {
        baseDirectoryURL.appendingPathComponent(safeFileName(meetingID) + ".json", isDirectory: false)
    }

    private func safeFileName(_ raw: String) -> String {
        let normalized = raw.replacingOccurrences(of: "/", with: "_")
        let allowed = normalized.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_" )).contains(scalar) {
                return Character(scalar)
            }
            return "_"
        }
        let value = String(allowed)
        return value.isEmpty ? "meeting" : value
    }
}

public actor SingleActiveMeetingRunGate: MeetingRunGating {
    private var activeMeetingIDs: Set<String> = []

    public init() {}

    public func beginIfPossible(meetingID: String) async -> Bool {
        if activeMeetingIDs.contains(meetingID) {
            return false
        }
        activeMeetingIDs.insert(meetingID)
        return true
    }

    public func end(meetingID: String) async {
        activeMeetingIDs.remove(meetingID)
    }
}
