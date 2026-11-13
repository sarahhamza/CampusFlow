//
//  ExtraViews.swift
//  sana
//
//  Created by Tekup-mac-4 on 6/11/2026.
//


import SwiftUI

struct CourseListView: View {
    @EnvironmentObject var store: StudyStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showAdd = false
    @State private var selectedDay = 0

    private var visible: [StudyCourse] {
        store.courses.filter { selectedDay == 0 || $0.weekday == selectedDay }
    }

    var body: some View {
        List {
            CourseOverviewCard(courses: store.courses, loading: store.coursesLoading)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 16, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            CourseDayFilter(selection: $selectedDay)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 16, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if store.coursesLoading {
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
                ForEach(visible) { course in
                    NavigationLink { CourseDetailView(course: course) } label: {
                        CourseCard(course: course)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                }
                .onDelete { offsets in
                    let selected = offsets.map { visible[$0] }
                    Task {
                        for course in selected { await store.delete(course: course) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86), value: selectedDay)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: store.courses)
        .screenTitle("courses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus").font(.headline).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(tr("add_course"))
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                CourseFormView(course: newCourse)
            }
        }
    }

    private var newCourse: StudyCourse {
        var course = StudyCourse.empty
        if selectedDay != 0 { course.weekday = selectedDay }
        return course
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 38, weight: .light)).foregroundStyle(.indigo)
                .frame(width: 80, height: 80)
                .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 26))
            Text(tr(store.courses.isEmpty ? "empty_courses" : "courses_day_empty")).font(.title3.bold())
            Text(tr(store.courses.isEmpty ? "empty_courses_hint" : "courses_day_hint"))
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { showAdd = true } label: {
                Label(tr("add_course"), systemImage: "plus").font(.headline)
            }
            .buttonStyle(.borderedProminent).tint(.indigo)
        }
        .padding(28).frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .modifier(CampusEntrance())
    }
}

struct CourseDetailView: View {

    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    let course: StudyCourse
    @State private var editing = false

    var current: StudyCourse {
        store.courses.first {
            $0.id == course.id
        } ?? course
    }

    var body: some View {
        Form {
            Section {
                CourseCard(course: current)
            }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            LabeledContent("name", value: current.name)
            LabeledContent("teacher", value: current.teacher)
            LabeledContent("room", value: current.room)
            LabeledContent("weekday", value: tr(CourseWeekday.key(for: current.weekday)))

            Button("edit") {
                editing = true
            }

            Button("delete", role: .destructive) {
                Task {
                    await store.delete(course: current)
                    dismiss()
                }
            }
        }
        .screenTitle("course_detail")
        .sheet(isPresented: $editing) {
            NavigationStack {
                CourseFormView(course: current)
            }
        }
    }
}

struct CourseFormView: View {

    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State var course: StudyCourse
    @State private var saving = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("course") {
                TextField("name", text: $course.name)
                TextField("teacher", text: $course.teacher)
                TextField("room", text: $course.room)

                Picker("weekday", selection: $course.weekday) {
                    Text("monday").tag(2)
                    Text("tuesday").tag(3)
                    Text("wednesday").tag(4)
                    Text("thursday").tag(5)
                    Text("friday").tag(6)
                    Text("saturday").tag(7)
                    Text("sunday").tag(1)
                }
            }

            if let message {
                Text(message)
                    .foregroundStyle(.red)
            }

            Button("save") {
                guard course.name.trimmingCharacters(
                    in: .whitespaces
                ).count >= 2 else {
                    message = tr("msg_course_name_short")
                    return
                }

                saving = true

                Task {
                    if await store.save(course: course) {
                        dismiss()
                    }
                    saving = false
                }
            }
            .disabled(saving)

            if saving {
                ProgressView()
            }
        }
        .screenTitle("course_form")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") {
                    dismiss()
                }
            }
        }
    }
}

struct FocusView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.scenePhase) private var phase

    @State private var remaining = 25 * 60
    @State private var running = false
    @State private var endDate: Date?

    @StateObject private var ad = InterstitialService()

    private let ticker = Timer.publish(
        every: 1,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(
                        .indigo.opacity(0.12),
                        lineWidth: 14
                    )

                Circle()
                    .trim(
                        from: 0,
                        to: CGFloat(remaining) / 1500
                    )
                    .stroke(
                        .indigo,
                        style: StrokeStyle(
                            lineWidth: 14,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        .easeInOut(duration: 0.5),
                        value: remaining
                    )

                VStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.largeTitle)
                        .symbolEffect(
                            .pulse,
                            options: .repeating,
                            isActive: running && !reduceMotion
                        )

                    Text(
                        String(
                            format: "%02d:%02d",
                            remaining / 60,
                            remaining % 60
                        )
                    )
                    .font(
                        .system(
                            size: 52,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()

                    Text("focus_message")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 275, height: 275)

            HStack(spacing: 16) {
                Button(running ? "pause" : "start") {
                    if running {
                        remaining = max(
                            0,
                            Int(
                                ceil(
                                    endDate?.timeIntervalSinceNow ?? 0
                                )
                            )
                        )
                        running = false
                        endDate = nil
                    } else {
                        endDate = Date().addingTimeInterval(
                            TimeInterval(remaining)
                        )
                        running = true
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("reset") {
                    running = false
                    remaining = 1500
                    endDate = nil
                }
                .buttonStyle(.bordered)
            }

            Text("ads_after_focus")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .screenTitle("focus")
        .onReceive(ticker) { _ in
            guard running, let endDate else { return }

            remaining = max(
                0,
                Int(ceil(endDate.timeIntervalSinceNow))
            )

            if remaining == 0 {
                running = false
                self.endDate = nil
                ad.show()
            }
        }
        .onChange(of: phase) { _, newValue in
            if newValue == .active,
               running,
               let endDate {
                remaining = max(
                    0,
                    Int(ceil(endDate.timeIntervalSinceNow))
                )
            }
        }
        .task {
            await ad.load()
        }
    }
}

struct WeatherView: View {

    @EnvironmentObject var weather: WeatherService
    @EnvironmentObject var location: LocationService
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 18) {
            Image(
                systemName: weather.snapshot?.current.symbol
                    ?? "cloud.sun.fill"
            )
            .symbolRenderingMode(.multicolor)
            .font(.system(size: 80))
            .symbolEffect(.breathe)
            .contentTransition(.symbolEffect(.replace))

            Text(
                String(
                    format: tr("weather_in"),
                    weather.place.name
                )
            )
            .font(.title2)

            if weather.loading && weather.snapshot == nil {
                ProgressView("loading")
            } else if let current = weather.snapshot?.current {
                Text("\(Int(current.temperature_2m))°C")
                    .font(
                        .system(size: 62, weight: .bold)
                    )

                Text(LocalizedStringKey(current.descriptionKey))
                    .font(.title3)
                    .foregroundStyle(.secondary)

                LabeledContent(
                    "humidity",
                    value: "\(current.relative_humidity_2m)%"
                )

                Text("data_source")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(
                    "weather_unavailable",
                    systemImage: "wifi.exclamationmark"
                )
            }

            locationSection

            if let error = weather.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button("refresh") {
                location.start()

                Task {
                    await weather.fetch(
                        for: location.place ?? .tunis
                    )
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .animation(.easeInOut(duration: 0.3), value: weather.snapshot?.current.weather_code)
        .screenTitle("weather")
    }

    @ViewBuilder
    private var locationSection: some View {
        if location.isDenied {
            VStack(spacing: 8) {
                Label(
                    "location_denied",
                    systemImage: "location.slash"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Button("open_settings") {
                    if let url = URL(
                        string: UIApplication.openSettingsURLString
                    ) {
                        openURL(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        } else if !location.isAuthorized {
            Button {
                location.start()
            } label: {
                Label(
                    "use_my_location",
                    systemImage: "location.fill"
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct ProfileView: View {

    @EnvironmentObject var auth: AuthService

    var body: some View {
        Form {
            Section("profile") {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 68)).foregroundStyle(.indigo.gradient)
                    Text(auth.user?.displayName ?? tr("student")).font(.title2.bold())
                    Text("CampusFlow").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: .infinity)

                LabeledContent(
                    "email",
                    value: auth.user?.email ?? "—"
                )
            }

            Section {
                NavigationLink { CalendarView() } label: { Label(tr("calendar"), systemImage: "calendar") }
                NavigationLink("settings") {
                    SettingsView()
                }

                NavigationLink("about") {
                    AboutView()
                }
            }

            Section {
                Button(
                    "logout",
                    role: .destructive
                ) {
                    auth.logout()
                }
            }
        }
        .screenTitle("profile")
    }
}

struct SettingsView: View {

    @EnvironmentObject var preferences: Preferences
    @EnvironmentObject var store: StudyStore
    @ObservedObject private var notifications = NotificationService.shared
    @Environment(\.openURL) private var openURL

    @AppStorage("reminders_enabled") private var remindersEnabled = false
    @AppStorage("reminder_lead") private var reminderLead = 60

    var body: some View {
        Form {
            Section("appearance") {
                Picker(
                    "theme",
                    selection: $preferences.theme
                ) {
                    Text("system").tag("system")
                    Text("light").tag("light")
                    Text("dark").tag("dark")
                }
            }

            Section("language") {
                Picker(
                    "language",
                    selection: $preferences.language
                ) {
                    Text("Français").tag("fr")
                    Text("English").tag("en")
                    Text("العربية").tag("ar")
                }
            }

            Section("reminders") {
                Toggle(
                    "reminders_enabled",
                    isOn: $remindersEnabled
                )

                if remindersEnabled {
                    Picker(
                        "reminder_lead",
                        selection: $reminderLead
                    ) {
                        Text("lead_15").tag(15)
                        Text("lead_60").tag(60)
                        Text("lead_1440").tag(1440)
                    }

                    Button("notif_test") {
                        Task {
                            await notifications.scheduleTest()
                        }
                    }
                }

                if notifications.authorization == .denied {
                    Label(
                        "notif_denied",
                        systemImage: "bell.slash"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Button("open_settings") {
                        if let url = URL(
                            string: UIApplication.openSettingsURLString
                        ) {
                            openURL(url)
                        }
                    }
                }
            }

            Section {
                Text("settings_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: remindersEnabled)
        .screenTitle("settings")
        .task {
            await notifications.refreshAuthorization()
        }
        .onChange(of: remindersEnabled) { _, enabled in
            Task {
                if enabled {
                    let granted = await notifications.requestAuthorization()

                    if !granted {
                        remindersEnabled = false
                    }
                }

                notifications.sync(tasks: store.tasks)
            }
        }
        .onChange(of: reminderLead) { _, _ in
            notifications.sync(tasks: store.tasks)
        }
        .onChange(of: preferences.language) { _, _ in
            // Les textes des rappels changent avec la langue.
            notifications.sync(tasks: store.tasks)
        }
    }
}

struct AboutView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(
                    systemName: "graduationcap.circle.fill"
                )
                .font(.system(size: 76))
                .foregroundStyle(.indigo)

                Text("CampusFlow")
                    .font(.largeTitle.bold())

                Text("version_info")

                Text("about_text")
                    .multilineTextAlignment(.center)

                Link(
                    "Open-Meteo",
                    destination: URL(
                        string: "https://open-meteo.com/"
                    )!
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .screenTitle("about")
    }
}