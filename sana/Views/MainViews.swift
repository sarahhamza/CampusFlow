//
//  MainViews.swift
//  sana
//
//  Created by Tekup-mac-4 on 6/11/2026.
//

import SwiftUI

struct MainTabs: View {

    @EnvironmentObject var store: StudyStore
    @EnvironmentObject var preferences: Preferences
    @SceneStorage("campus_selected_tab") private var selection = 0
    @StateObject private var weather = WeatherService()
    @StateObject private var location = LocationService()

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label(tr("home"), systemImage: "house")
            }
            .tag(0)

            NavigationStack {
                TaskListView()
            }
            .tabItem {
                Label(tr("tasks"), systemImage: "checklist")
            }
            .tag(1)

            NavigationStack {
                CourseListView()
            }
            .tabItem {
                Label(tr("courses"), systemImage: "books.vertical")
            }
            .tag(2)

            NavigationStack {
                FocusView()
            }
            .tabItem {
                Label(tr("focus"), systemImage: "timer")
            }
            .tag(3)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label(tr("profile"), systemImage: "person.crop.circle")
            }
            .tag(4)
        }
        // Reconstruit les onglets quand la langue change : la barre d'onglets
        // et les titres (UIKit) reprennent alors la bonne langue et le bon sens
        // d'écriture (le sens RTL ne « collait » pas sur l'onglet Profil).
        .tint(.indigo)
        .overlay(alignment: .top) {
            if let error = store.error {
                ErrorToast(message: error) {
                    store.error = nil
                }
            }
        }
        .environmentObject(weather)
        .environmentObject(location)
        .task {
            // Météo de Tunis tout de suite, puis de la vraie position dès
            // qu'elle est connue (ou si l'autorisation est accordée plus tard).
            location.start()
            await weather.fetch(for: location.place ?? .tunis)
        }
        .onChange(of: location.place) { _, newPlace in
            guard let newPlace else { return }

            Task {
                await weather.fetch(for: newPlace)
            }
        }
    }
}

struct ErrorToast: View {

    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(message).font(.caption)
            Spacer()
            Button("×", action: dismiss)
        }
        .padding()
        .background(
            .red.opacity(0.92),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .foregroundStyle(.white)
        .padding()
    }
}

struct DashboardView: View {

    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: StudyStore
    @EnvironmentObject var weather: WeatherService

    var finished: Int {
        store.tasks.filter(\.isDone).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(String(format: tr("hello"), auth.user?.displayName ?? tr("student")))
                    .font(.title.bold())

                Text("welcome_dashboard")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    Label(tr("focus_message"), systemImage: "sparkles").font(.headline)
                    ProgressView(value: store.tasks.isEmpty ? 0 : Double(finished) / Double(store.tasks.count))
                        .tint(.white)
                    Text("\(finished) / \(store.tasks.count) \(tr("completed"))").font(.caption)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.white)
                .background(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))

                HStack(spacing: 12) {
                    MetricCard(
                        value: "\(store.tasks.count)",
                        label: "tasks",
                        icon: "list.bullet.rectangle",
                        color: .indigo
                    )

                    MetricCard(
                        value: "\(finished)",
                        label: "completed",
                        icon: "checkmark.seal",
                        color: .green
                    )

                    MetricCard(
                        value: "\(store.courses.count)",
                        label: "courses",
                        icon: "books.vertical",
                        color: .orange
                    )
                }

                NavigationLink {
                    WeatherView()
                } label: {
                    HStack {
                        Image(
                            systemName: weather.snapshot?.current.symbol
                                ?? "cloud.sun.fill"
                        )
                        .symbolRenderingMode(.multicolor)
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))

                        VStack(alignment: .leading) {
                            Text(
                                String(
                                    format: tr("weather_in"),
                                    weather.place.name
                                )
                            )
                            .font(.headline)

                            if weather.loading && weather.snapshot == nil {
                                ProgressView()
                            } else if let current = weather.snapshot?.current {
                                Text(
                                    "\(Int(current.temperature_2m))°C · \(tr(current.descriptionKey))"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            } else {
                                Text("weather_unavailable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    NavigationLink { CalendarView() } label: {
                        Label(tr("calendar"), systemImage: "calendar")
                            .frame(maxWidth: .infinity).padding()
                            .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    }

                    NavigationLink { RevisionPlanView() } label: {
                        Label(tr("revision_plan"), systemImage: "sparkles")
                            .frame(maxWidth: .infinity).padding()
                            .background(.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .buttonStyle(.plain)

                Text("upcoming_tasks")
                    .font(.title3.bold())

                if store.loading {
                    ProgressView("loading")
                        .frame(maxWidth: .infinity)
                } else if store.tasks.filter({
                    !$0.isDone
                }).isEmpty {
                    ContentUnavailableView(
                        "empty_tasks",
                        systemImage: "checkmark.circle",
                        description: Text("empty_tasks_hint")
                    )
                } else {
                    ForEach(
                        Array(
                            store.tasks
                                .filter { !$0.isDone }
                                .prefix(4)
                        )
                    ) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            TaskRow(task: task)
                        }
                        .buttonStyle(.plain)
                    }
                }

                TestBanner()
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .screenTitle("dashboard")
    }
}

struct MetricCard: View {

    let value: String
    let label: LocalizedStringKey
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)

            Text(value)
                .font(.title.bold())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            color.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

struct TaskListView: View {
    @EnvironmentObject var store: StudyStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showAdd = false
    @State private var filter = 0

    private var finished: Int { store.tasks.filter(\.isDone).count }

    private var visible: [StudyTask] {
        store.tasks.filter {
            filter == 0 || (filter == 1 && !$0.isDone) || (filter == 2 && $0.isDone)
        }
    }

    var body: some View {
        List {
            TaskOverviewCard(total: store.tasks.count, completed: finished, loading: store.loading)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 16, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            TaskFilterBar(selection: $filter, counts: [store.tasks.count, store.tasks.count - finished, finished])
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 16, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if store.loading {
                ProgressView(tr("loading"))
                    .frame(maxWidth: .infinity).padding(40)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if visible.isEmpty {
                emptyState
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(visible) { task in
                    NavigationLink { TaskDetailView(task: task) } label: {
                        TaskRow(task: task)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                }
                .onDelete { offsets in
                    let selected = offsets.map { visible[$0] }
                    Task {
                        for task in selected { await store.delete(task: task) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86), value: filter)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: store.tasks)
        .screenTitle("tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(tr("add_task"))
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack { TaskFormView(task: .empty) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: filter == 2 ? "checkmark.seal" : "tray")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.indigo)
                .frame(width: 80, height: 80)
                .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 26))
            Text(tr(store.tasks.isEmpty ? "empty_tasks" : "tasks_filter_empty"))
                .font(.title3.bold())
            Text(tr(store.tasks.isEmpty ? "empty_tasks_hint" : "tasks_filter_hint"))
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if store.tasks.isEmpty {
                Button { showAdd = true } label: {
                    Label(tr("add_task"), systemImage: "plus").font(.headline)
                }
                .buttonStyle(.borderedProminent).tint(.indigo)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .modifier(CampusEntrance())
    }
}

struct TaskDetailView: View {

    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    let task: StudyTask
    @State private var editing = false

    var current: StudyTask {
        store.tasks.first {
            $0.id == task.id
        } ?? task
    }

    var body: some View {
        Form {
            Section("details") {
                LabeledContent(
                    "title",
                    value: current.title
                )

                LabeledContent(
                    "course",
                    value: current.course
                )

                LabeledContent(
                    "deadline",
                    value: current.dueDate.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )

                Text(
                    current.details.isEmpty
                        ? "—"
                        : current.details
                )
            }

            Section {
                Button(
                    current.isDone
                        ? "mark_pending"
                        : "mark_completed"
                ) {
                    var revised = current
                    revised.isDone.toggle()

                    Task {
                        _ = await store.save(task: revised)
                    }
                }

                Button("edit") {
                    editing = true
                }

                Button("delete", role: .destructive) {
                    Task {
                        await store.delete(task: current)
                        dismiss()
                    }
                }
            }
        }
        .screenTitle("task_detail")
        .sheet(isPresented: $editing) {
            NavigationStack {
                TaskFormView(task: current)
            }
        }
    }
}

struct TaskFormView: View {

    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State var task: StudyTask
    @State private var saving = false
    @State private var validation: String?

    var body: some View {
        Form {
            Section("details") {
                TextField("title", text: $task.title)

                TextField(
                    "description",
                    text: $task.details,
                    axis: .vertical
                )
                .lineLimit(2...5)

                TextField("course", text: $task.course)

                DatePicker(
                    "deadline",
                    selection: $task.dueDate
                )

                Picker("priority", selection: $task.priority) {
                    Text("low").tag(1)
                    Text("medium").tag(2)
                    Text("high").tag(3)
                }

                Toggle(
                    "completed",
                    isOn: $task.isDone
                )
            }

            if let validation {
                Text(validation)
                    .foregroundStyle(.red)
            }

            Section {
                Button("save") {
                    save()
                }
                .disabled(saving)

                if saving {
                    ProgressView()
                }
            }
        }
        .screenTitle("task_form")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") {
                    dismiss()
                }
            }
        }
    }

    func save() {
        guard task.title.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).count >= 3 else {
            validation = tr("msg_title_short")
            return
        }

        guard !task.course.trimmingCharacters(
            in: .whitespaces
        ).isEmpty else {
            validation = tr("msg_course_required")
            return
        }

        saving = true

        Task {
            if await store.save(task: task) {
                dismiss()
            }
            saving = false
        }
    }
}
