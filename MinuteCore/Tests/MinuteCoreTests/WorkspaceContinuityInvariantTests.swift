import Testing
@testable import MinuteCore

struct WorkspaceContinuityInvariantTests {
    @Test
    func isPreserved_whenAllFieldsMatch() {
        let before = WorkspaceContinuitySnapshot(
            isRecordingActive: true,
            pipelineStage: "recording",
            activeSessionID: "session-1",
            unsavedWorkPresent: true
        )

        let after = WorkspaceContinuitySnapshot(
            isRecordingActive: true,
            pipelineStage: "recording",
            activeSessionID: "session-1",
            unsavedWorkPresent: true
        )

        #expect(WorkspaceContinuityInvariant.isPreserved(before: before, after: after))
        #expect(WorkspaceContinuityInvariant.violations(before: before, after: after).isEmpty)
    }

    @Test
    func violations_reportsChangedFields() {
        let before = WorkspaceContinuityFixtures.activeRecording()
        let after = WorkspaceContinuitySnapshot(
            isRecordingActive: false,
            pipelineStage: "processing",
            activeSessionID: "session-2",
            unsavedWorkPresent: false
        )

        let violations = WorkspaceContinuityInvariant.violations(before: before, after: after)

        #expect(violations.contains("isRecordingActive"))
        #expect(violations.contains("pipelineStage"))
        #expect(violations.contains("activeSessionID"))
        #expect(violations.contains("unsavedWorkPresent"))
        #expect(WorkspaceContinuityInvariant.isPreserved(before: before, after: after) == false)
    }
}
