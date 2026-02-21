import Foundation
@testable import MinuteCore

enum WorkspaceContinuityFixtures {
    static func activeRecording() -> WorkspaceContinuitySnapshot {
        WorkspaceContinuitySnapshot(
            isRecordingActive: true,
            pipelineStage: "recording",
            activeSessionID: "session-1",
            unsavedWorkPresent: true
        )
    }

    static func processingSession() -> WorkspaceContinuitySnapshot {
        WorkspaceContinuitySnapshot(
            isRecordingActive: false,
            pipelineStage: "processing",
            activeSessionID: "session-2",
            unsavedWorkPresent: true
        )
    }
}
