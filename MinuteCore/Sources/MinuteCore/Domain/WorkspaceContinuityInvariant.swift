import Foundation

public struct WorkspaceContinuitySnapshot: Sendable, Equatable {
    public var isRecordingActive: Bool
    public var pipelineStage: String
    public var activeSessionID: String?
    public var unsavedWorkPresent: Bool

    public init(
        isRecordingActive: Bool,
        pipelineStage: String,
        activeSessionID: String?,
        unsavedWorkPresent: Bool
    ) {
        self.isRecordingActive = isRecordingActive
        self.pipelineStage = pipelineStage
        self.activeSessionID = activeSessionID
        self.unsavedWorkPresent = unsavedWorkPresent
    }
}

public enum WorkspaceContinuityInvariant {
    public static func violations(
        before: WorkspaceContinuitySnapshot,
        after: WorkspaceContinuitySnapshot
    ) -> [String] {
        var results: [String] = []

        if before.isRecordingActive != after.isRecordingActive {
            results.append("isRecordingActive")
        }
        if before.activeSessionID != after.activeSessionID {
            results.append("activeSessionID")
        }
        if before.unsavedWorkPresent != after.unsavedWorkPresent {
            results.append("unsavedWorkPresent")
        }
        if before.pipelineStage != after.pipelineStage {
            results.append("pipelineStage")
        }

        return results
    }

    public static func isPreserved(
        before: WorkspaceContinuitySnapshot,
        after: WorkspaceContinuitySnapshot
    ) -> Bool {
        violations(before: before, after: after).isEmpty
    }
}
