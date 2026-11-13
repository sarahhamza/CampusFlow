import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var date = Date.now
    @State private var editing: CalendarEvent?
    private var events: [CalendarEvent] {
        guard let interval = Calendar.current.dateInterval(of: .day, for: date) else { return [] }
        return store.events.filter { $0.start < interval.end && $0.end > interval.start }
    }
    private var tasks: [StudyTask] {
        store.tasks.filter { Calendar.current.isDate($0.dueDate, inSameDayAs: date) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DatePicker(tr("calendar"), selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical).padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                Text(date, format: .dateTime.weekday(.wide).day().month(.wide)).font(.title3.bold())
                if store.eventsLoading { ProgressView(tr("loading")) }
                if events.isEmpty && tasks.isEmpty && !store.eventsLoading {
                    ContentUnavailableView(tr("empty_events"), systemImage: "calendar.badge.plus", description: Text(tr("empty_events_hint")))
                }
                ForEach(events) { event in
                    Button { editing = event } label: {
                        HStack(spacing: 14) {
                            Image(systemName: event.kind == "exam" ? "graduationcap.fill" : "book.closed.fill")
                                .font(.title2).foregroundStyle(.indigo)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(event.title).font(.headline)
                                Text(event.course).font(.subheadline).foregroundStyle(.secondary)
                                Text(event.start, format: .dateTime.hour().minute()).font(.caption)
                            }
                            Spacer()
                            Image(systemName: "pencil").foregroundStyle(.secondary)
                        }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                }
                ForEach(tasks) { task in
                    NavigationLink { TaskDetailView(task: task) } label: { TaskRow(task: task) }.buttonStyle(.plain)
                }
            }.padding()
        }
        .screenTitle("calendar")
        .toolbar {
            Button { var event = CalendarEvent(); event.start = date; event.end = date.addingTimeInterval(3600); editing = event } label: {
                Label(tr("add_event"), systemImage: "plus")
            }
        }
        .sheet(item: $editing) { event in NavigationStack { EventFormView(event: event) } }
        .animation(.smooth, value: date)
    }
}

struct EventFormView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @State var event: CalendarEvent
    @State private var saving = false
    @State private var message: String?
    @State private var confirmDelete = false
    var body: some View {
        Form {
            Section(tr("details")) {
                TextField(tr("title"), text: $event.title)
                TextField(tr("course"), text: $event.course)
                Picker(tr("event_kind"), selection: $event.kind) {
                    Text(tr("study")).tag("study")
                    Text(tr("exam")).tag("exam")
                }
                DatePicker(tr("event_start"), selection: $event.start)
                DatePicker(tr("event_end"), selection: $event.end)
                TextField(tr("description"), text: $event.notes, axis: .vertical).lineLimit(3...8)
            }
            if let message { Text(message).foregroundStyle(.red) }
            Section {
                Button(tr("save")) {
                    saving = true
                    Task {
                        if await store.save(event: event) { dismiss() }
                        else { message = store.error }
                        saving = false
                    }
                }
                if store.events.contains(where: { $0.id == event.id }) {
                    Button(tr("delete"), role: .destructive) { confirmDelete = true }
                }
                if saving { ProgressView() }
            }.disabled(saving)
        }
        .onAppear {
            if !["study", "exam"].contains(event.kind) { event.kind = "study" }
        }
        .screenTitle("add_event")
        .toolbar { Button(tr("cancel")) { dismiss() }.disabled(saving) }
        .confirmationDialog(tr("delete"), isPresented: $confirmDelete) {
            Button(tr("delete"), role: .destructive) {
                saving = true
                Task {
                    if await store.delete(event: event) { dismiss() } else { message = store.error }
                    saving = false
                }
            }
        }
    }
}
