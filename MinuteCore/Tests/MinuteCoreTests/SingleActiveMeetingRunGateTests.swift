import Testing
@testable import MinuteCore

struct SingleActiveMeetingRunGateTests {
    @Test
    func beginIfPossibleRejectsDuplicateActiveMeeting() async {
        let gate = SingleActiveMeetingRunGate()

        let first = await gate.beginIfPossible(meetingID: "meeting-1")
        let second = await gate.beginIfPossible(meetingID: "meeting-1")

        #expect(first)
        #expect(!second)
    }

    @Test
    func endAllowsMeetingToStartAgain() async {
        let gate = SingleActiveMeetingRunGate()

        _ = await gate.beginIfPossible(meetingID: "meeting-2")
        await gate.end(meetingID: "meeting-2")
        let third = await gate.beginIfPossible(meetingID: "meeting-2")

        #expect(third)
    }

    @Test
    func differentMeetingsCanRunConcurrently() async {
        let gate = SingleActiveMeetingRunGate()

        let first = await gate.beginIfPossible(meetingID: "meeting-a")
        let second = await gate.beginIfPossible(meetingID: "meeting-b")

        #expect(first)
        #expect(second)
    }
}
