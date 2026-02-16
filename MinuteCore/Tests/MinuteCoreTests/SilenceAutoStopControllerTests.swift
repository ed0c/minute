import Foundation
import MinuteCore
import Testing

struct SilenceAutoStopControllerTests {
    @Test
    func sustainedSilence_startsWarning_thenTriggersAutoStopAfterCountdown() async throws {
        let events = SilenceEventRecorder()
        let policy = SilenceDetectionPolicy(
            silenceDurationSeconds: 0.15,
            warningCountdownSeconds: 0.15,
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
        await controller.start(sessionID: sessionID, startedAt: Date())

        let t0 = Date()
        await controller.ingest(level: 0.0, at: t0)
        await controller.ingest(level: 0.0, at: t0.addingTimeInterval(0.2))

        try await Task.sleep(nanoseconds: 300_000_000)

        let snapshot = await controller.status()
        #expect(snapshot.phase == .autoStopExecuted)

        let seenWarning = await events.containsWarningStarted
        let seenAutoStop = await events.containsAutoStop
        #expect(seenWarning)
        #expect(seenAutoStop)
    }
}

private actor SilenceEventRecorder {
    private var events: [SilenceAutoStopEvent] = []

    var containsWarningStarted: Bool {
        events.contains {
            if case .warningStarted = $0 { return true }
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
