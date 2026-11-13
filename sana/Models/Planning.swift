import Foundation

struct CalendarEvent: Identifiable, Hashable {
    var id = UUID().uuidString
    var title = ""
    var course = ""
    var notes = ""
    var start = Date.now
    var end = Date.now.addingTimeInterval(3600)
    var kind = "study"

    var document: [String: Any] {
        ["title": title, "course": course, "notes": notes, "start": start,
         "end": end, "kind": kind]
    }
}
