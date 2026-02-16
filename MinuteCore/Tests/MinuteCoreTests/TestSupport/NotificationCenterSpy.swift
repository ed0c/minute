import Foundation

actor NotificationCenterSpy {
    struct Event: Sendable {
        var name: Notification.Name
        var objectDescription: String?
    }

    private(set) var events: [Event] = []

    func record(name: Notification.Name, object: Any?) {
        let description = object.map { String(describing: $0) }
        events.append(Event(name: name, objectDescription: description))
    }

    func count(name: Notification.Name) -> Int {
        events.filter { $0.name == name }.count
    }

    func clear() {
        events.removeAll()
    }
}
