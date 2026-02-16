import Foundation

actor SilenceAutoStopTestClock {
    private var nowValue: Date

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.nowValue = now
    }

    func now() -> Date {
        nowValue
    }

    func advance(seconds: TimeInterval) {
        nowValue = nowValue.addingTimeInterval(seconds)
    }
}
