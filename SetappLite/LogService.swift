import Foundation
import Combine

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let appName: String
    let event: Event
    let detail: String?

    enum Event: String {
        case installed = "Installed"
        case updated = "Updated"
        case deleted = "Deleted"
        case failed = "Failed"
    }
}

@MainActor
class LogService: ObservableObject {
    @Published var entries: [LogEntry] = []

    func log(_ event: LogEntry.Event, app: String, detail: String? = nil) {
        let entry = LogEntry(date: Date(), appName: app, event: event, detail: detail)
        entries.insert(entry, at: 0)
        // Keep last 200 entries
        if entries.count > 200 {
            entries = Array(entries.prefix(200))
        }
    }
}
