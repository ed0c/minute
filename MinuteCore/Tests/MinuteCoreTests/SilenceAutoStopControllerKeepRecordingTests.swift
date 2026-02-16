import Foundation
import MinuteCore
import Testing

struct SilenceAutoStopControllerKeepRecordingTests {
    @Test
    func keepRecording_cancelsPendingAutoStop() async throws {
        let events = SilenceEventRecorder()
        let policy = SilenceDetectionPolicy(
            silenceDurationSeconds: 0.15,
            warningCountdownSeconds: 0.3,
            rmsSilenceThreshold: 0.5,
            transientToleranceSeconds: 0
        )
        let controller = SilenceAutoStopController(
            policy: policy,
            onEvent: { event in
                Task { await events.append(event) }
            }
        )

        let sessionID = UUID()
        let t0 = Date()
        await controller.start(sessionID: sessionID, startedAt: t0)
        await controller.ingest(level: 0.0, at: t0)
        await controller.ingest(level: 0.0, at: t0.addingTimeInterval(0.2))

        await controller.keepRecording()
        try await Task.sleep(nanoseconds: 450_000_000)

        let snapshot = await controller.status()
        #expect(snapshot.phase == .monitoring)

        let sawCancelByUser = await events.containsCancelByUser
        let sawAutoStop = await events.containsAutoStop
        #expect(sawCancelByUser)
        #expect(!sawAutoStop)
    }

    @Test
    func resumedSpeech_cancelsWarningCountdown() async throws {
        let events = SilenceEventRecorder()
        let policy = SilenceDetectionPolicy(
            silenceDurationSeconds: 0.1,
            warningCountdownSeconds: 0.3,
            rmsSilenceThreshold: 0.5,
            transientToleranceSeconds: 0
        )
        let controller = SilenceAutoStopController(
            policy: policy,
            onEvent: { event in
                Task { await events.append(event) }
            }
        )

        let t0 = Date()
        await controller.start(sessionID: UUID(), startedAt: t0)
        await controller.ingest(level: 0.0, at: t0)
        await controller.ingest(level: 0.0, at: t0.addingTimeInterval(0.15))

        await controller.ingest(level: 1.0, at: t0.addingTimeInterval(0.16))
        try await Task.sleep(nanoseconds: 350_000_000)

        let snapshot = await controller.status()
        #expect(snapshot.phase == .monitoring)
        let sawCancelBySpeech = await events.containsCancelBySpeech
        #expect(sawCancelBySpeech)
    }
}

private actor SilenceEventRecorder {
    private var events: [SilenceAutoStopEvent] = []

    var containsCancelByUser: Bool {
        events.contains {
            if case .warningCanceledByUser = $0 { return true }
            return false
        }
    }

    var containsCancelBySpeech: Bool {
        events.contains {
            if case .warningCanceledBySpeech = $0 { return true }
            return false
        }
    }

    var containsAutoStop: Bool {
        events.contains {
            if case .autoStopTriggered = $0 { return true }
            return false
        }
    }

    func append(_ event: SilenceAutoStopEvent) {
        events.append(event)
    }
}
