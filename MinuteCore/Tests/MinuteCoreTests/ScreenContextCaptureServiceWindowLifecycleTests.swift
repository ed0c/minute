import Foundation
import Testing
@testable import MinuteCore

struct ScreenContextCaptureServiceWindowLifecycleTests {
    @Test
    func closedWindow_emitsLifecycleEventOnce() async throws {
        let inferencer = MockScreenContextInferenceService()
        let service = ScreenContextCaptureService(inferencer: inferencer)
        let recorder = LifecycleEventRecorder()

        try await service._testStartCapture(
            sources: [makeClosedWindowTestSource()],
            minimumFrameInterval: 1.0,
            lifecycleEventHandler: { event in
                Task { await recorder.append(event) }
            }
        )

        try await Task.sleep(nanoseconds: 150_000_000)
        _ = await service.stopCapture()

        let events = await recorder.events
        #expect(events.count == 1)
        #expect(events.first?.type == .sharedWindowClosed)
    }

    @Test
    func transientFailure_doesNotEmitWindowClosedEvent() async throws {
        let inferencer = MockScreenContextInferenceService()
        let service = ScreenContextCaptureService(inferencer: inferencer)
        let recorder = LifecycleEventRecorder()

        try await service._testStartCapture(
            sources: [makeTransientFailureTestSource()],
            minimumFrameInterval: 1.0,
            lifecycleEventHandler: { event in
                Task { await recorder.append(event) }
            }
        )

        try await Task.sleep(nanoseconds: 150_000_000)
        _ = await service.stopCapture()

        let events = await recorder.events
        #expect(events.isEmpty)
    }
}

private actor LifecycleEventRecorder {
    private(set) var events: [ScreenContextLifecycleEvent] = []

    func append(_ event: ScreenContextLifecycleEvent) {
        events.append(event)
    }
}
