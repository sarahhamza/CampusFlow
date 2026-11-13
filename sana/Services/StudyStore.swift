//
//  StudyStore.swift
//  sana
//
//  Created by Tekup-mac-4 on 6/11/2026.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class StudyStore: ObservableObject {

    @Published private(set) var tasks: [StudyTask] = []
    @Published private(set) var courses: [StudyCourse] = []
    @Published var loading = false
    @Published var coursesLoading = false
    @Published var error: String?

    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var eventsLoading = false
    private var eventListener: ListenerRegistration?

    private var taskListener: ListenerRegistration?
    private var courseListener: ListenerRegistration?
    private var uid: String?

    private var root: DocumentReference? {
        guard let uid else { return nil }
        return Firestore.firestore()
            .collection("users")
            .document(uid)
    }

    func start(uid: String) {
        guard self.uid != uid else { return }

        stop()
        self.uid = uid
        loading = true
        coursesLoading = true

        guard let root else { return }
        eventsLoading = true
        eventListener = root.collection("events").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self, self.uid == uid else { return }
                self.eventsLoading = false
                if let error { self.error = error.localizedDescription; return }
                self.events = (snapshot?.documents ?? []).compactMap { doc in
                    let d = doc.data()
                    guard let start = d["start"] as? Timestamp,
                          let end = d["end"] as? Timestamp else { return nil }
                    return CalendarEvent(id: doc.documentID, title: d["title"] as? String ?? "",
                        course: d["course"] as? String ?? "", notes: d["notes"] as? String ?? "",
                        start: start.dateValue(), end: end.dateValue(), kind: d["kind"] as? String ?? "study")
                }.sorted { $0.start < $1.start }
            }
        }


        taskListener = root.collection("tasks")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.uid == uid else { return }

                    self.loading = false

                    if let error {
                        self.error = error.localizedDescription
                        return
                    }

                    self.tasks = (snapshot?.documents ?? []).map { doc in
                        let d = doc.data()

                        return StudyTask(
                            id: doc.documentID,
                            title: d["title"] as? String ?? "",
                            details: d["details"] as? String ?? "",
                            course: d["course"] as? String ?? "General",
                            dueDate: (d["dueDate"] as? Timestamp)?
                                .dateValue() ?? .now,
                            priority: d["priority"] as? Int ?? 1,
                            isDone: d["isDone"] as? Bool ?? false
                        )
                    }
                    .sorted { $0.dueDate < $1.dueDate }

                    NotificationService.shared.sync(tasks: self.tasks)
                }
            }

        courseListener = root.collection("courses")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.uid == uid else { return }

                    self.coursesLoading = false

                    if let error {
                        self.error = error.localizedDescription
                        return
                    }

                    self.courses = (snapshot?.documents ?? []).map { doc in
                        let d = doc.data()

                        return StudyCourse(
                            id: doc.documentID,
                            name: d["name"] as? String ?? "",
                            teacher: d["teacher"] as? String ?? "",
                            room: d["room"] as? String ?? "",
                            weekday: d["weekday"] as? Int ?? 2
                        )
                    }
                    .sorted {
                        $0.name.localizedStandardCompare($1.name)
                            == .orderedAscending
                    }
                }
            }
    }

    func stop() {
        eventListener?.remove()
        eventListener = nil
        events = []
        eventsLoading = false
        taskListener?.remove()
        courseListener?.remove()

        taskListener = nil
        courseListener = nil
        uid = nil

        NotificationService.shared.clear()

        tasks = []
        courses = []
        loading = false
        coursesLoading = false
        error = nil
    }

    func save(task: StudyTask) async -> Bool {
        guard let root else {
            error = tr("msg_not_signed_in")
            return false
        }

        do {
            try await root.collection("tasks")
                .document(task.id)
                .setData(task.asDocument)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func save(course: StudyCourse) async -> Bool {
        guard let root else {
            error = tr("msg_not_signed_in")
            return false
        }

        do {
            try await root.collection("courses")
                .document(course.id)
                .setData(course.asDocument)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func delete(task: StudyTask) async {
        do {
            try await root?.collection("tasks")
                .document(task.id)
                .delete()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(course: StudyCourse) async {
        do {
            try await root?.collection("courses")
                .document(course.id)
                .delete()
        } catch {
            self.error = error.localizedDescription
        }
    }
}


extension StudyStore {
    func save(event: CalendarEvent) async -> Bool {
        guard let root else { error = tr("msg_not_signed_in"); return false }
        guard event.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3,
              event.title.count <= 200, event.course.count <= 200, event.notes.count <= 10000,
              event.end > event.start else { error = tr("event_invalid"); return false }
        do {
            try await root.collection("events").document(event.id).setData(event.document)
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func delete(event: CalendarEvent) async -> Bool {
        guard let root else { error = tr("msg_not_signed_in"); return false }
        do {
            try await root.collection("events").document(event.id).delete()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func save(plan: RevisionPlan, starting date: Date) async -> Bool {
        guard let root else { error = tr("msg_not_signed_in"); return false }
        let batch = Firestore.firestore().batch()
        var offsets: [Int: Int] = [:]
        for session in plan.sessions {
            guard let day = Calendar.current.date(byAdding: .day, value: session.day - 1, to: date),
                  let morning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) else { continue }
            let anchor = Calendar.current.isDateInToday(morning) ? max(morning, Date.now.addingTimeInterval(60)) : morning
            var start = anchor.addingTimeInterval(Double(offsets[session.day, default: 0]) * 60)
            for existing in events.sorted(by: { $0.start < $1.start }) {
                if start < existing.end && start.addingTimeInterval(Double(session.minutes) * 60) > existing.start {
                    start = existing.end.addingTimeInterval(600)
                }
            }
            offsets[session.day] = Int(start.timeIntervalSince(anchor) / 60) + session.minutes + 10
            let event = CalendarEvent(id: "revision-\(session.id)", title: session.title,
                course: session.course, notes: session.instructions, start: start,
                end: start.addingTimeInterval(Double(session.minutes) * 60), kind: "revision")
            batch.setData(event.document, forDocument: root.collection("events").document(event.id))
        }
        do { try await batch.commit(); return true }
        catch { self.error = error.localizedDescription; return false }
    }
}
