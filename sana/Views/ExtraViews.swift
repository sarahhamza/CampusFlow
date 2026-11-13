//
//  ExtraViews.swift
//  sana
//
//  Created by Tekup-mac-4 on 6/11/2026.
//


import SwiftUI

struct CourseListView: View {

    @EnvironmentObject var store: StudyStore
    @State private var showAdd = false

    var body: some View {
        Group {
            if store.coursesLoading {
                ProgressView("loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.courses.isEmpty {
                ContentUnavailableView(
                    "empty_courses",
                    systemImage: "books.vertical",
                    description: Text("empty_courses_hint")
                )
            } else {
                List {
                    ForEach(store.courses) { course in
                        NavigationLink {
                            CourseDetailView(course: course)
                        } label: {
                            CourseCard(course: course)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
                        )
                    }
                    .onDelete { offsets in
                        let selected = offsets.map {
                            store.courses[$0]
                        }
                        Task {
                            for course in selected {
                                await store.delete(course: course)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
            }
        }
        .screenTitle("courses")
        .toolbar {
            Button {
                showAdd = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                CourseFormView(course: .empty)
            }
        }
    }
}

/// Carte d'un cours : pastille colorée, enseignant, salle et jour.
struct CourseCard: View {

    let course: StudyCourse

    private static let palette: [Color] = [
        .indigo, .purple, .teal, .orange, .pink, .blue
    ]

    private var accent: Color {
        let seed = course.name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.palette[seed % Self.palette.count]
    }

    private var dayKey: String {
        ["sunday", "monday", "tuesday", "wednesday",
         "thursday", "friday", "saturday"][(course.weekday - 1 + 7) % 7]
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(String(course.name.prefix(1)).uppercased())
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(course.name)
                    .font(.headline)

                Label(course.teacher, systemImage: "person")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label(course.room, systemImage: "door.left.hand.open")
                    Text(tr(dayKey))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(accent.opacity(0.14), in: Capsule())
                        .foregroundStyle(accent)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: 700)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
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
            LabeledContent("name", value: current.name)
            LabeledContent("teacher", value: current.teacher)
            LabeledContent("room", value: current.room)
            LabeledContent("weekday", value: "\(current.weekday)")

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
                            isActive: running
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
                Label(
                    auth.user?.displayName ?? tr("student"),
                    systemImage: "person.crop.circle.fill"
                )

                LabeledContent(
                    "email",
                    value: auth.user?.email ?? "—"
                )
            }

            Section {
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