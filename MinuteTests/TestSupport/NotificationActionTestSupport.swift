import Foundation
import Testing

@testable import Minute

func postKeepRecordingNotificationAction() {
    NotificationCenter.default.post(name: .minuteRecordingAlertKeepRecording, object: nil)
}

func waitForMainQueue() async {
    await MainActor.run {}
    try? await Task.sleep(nanoseconds: 10_000_000)
}
