import SwiftUI

struct RevisionPlanView: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var store: StudyStore
    @StateObject private var service = RevisionService()
    @State private var subjects = ""
    @State private var days = 7
    @State private var minutes = 60
    @State private var starting = Date.now
    @State private var saving = false
    @State private var saved = false
    @State private var saveError: String?
    @State private var request: Task<Void, Never>?

    var body: some View {
        Form {
            Section {
                Label(tr("revision_plan"), systemImage: "sparkles").font(.title2.bold()).foregroundStyle(.indigo)
                Text(tr("ai_intro")).foregroundStyle(.secondary)
                TextField(tr("subjects_hint"), text: $subjects, axis: .vertical).lineLimit(3...6)
                Stepper("\(tr("plan_days")): \(days)", value: $days, in: 1...28)
                Stepper("\(tr("daily_minutes")): \(minutes)", value: $minutes, in: 30...240, step: 15)
                DatePicker(tr("event_start"), selection: $starting, in: Date.now..., displayedComponents: .date)
                Text(tr("ai_consent")).font(.footnote).foregroundStyle(.secondary)
                Button {
                    saved = false
                    saveError = nil
                    request = Task { await service.generate(subjects: subjects, days: days, minutes: minutes, language: preferences.language) }
                } label: { Label(tr("generate_plan"), systemImage: "sparkles") }
                .disabled(subjects.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || service.working)
                if service.working { ProgressView(tr("generating_plan")) }
                if let error = service.error { Text(error).foregroundStyle(.red) }
            }.disabled(saving)
            if let plan = service.plan {
                Section(tr("your_plan")) {
                    Text(plan.summary).font(.headline)
                    ForEach(plan.sessions) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(tr("plan_day")) \(session.day) · \(session.minutes) \(tr("minutes"))").font(.caption.bold()).foregroundStyle(.teal)
                            Text(session.title).font(.headline)
                            Text(session.course).font(.subheadline).foregroundStyle(.secondary)
                            Text(session.instructions).font(.subheadline)
                        }.padding(.vertical, 8)
                    }
                    Button {
                        saving = true
                        Task {
                            saved = await store.save(plan: plan, starting: starting)
                            saveError = saved ? nil : store.error
                            saving = false
                        }
                    } label: { Label(tr(saved ? "plan_saved" : "save_to_calendar"), systemImage: saved ? "checkmark.circle.fill" : "calendar.badge.plus") }
                    .disabled(saving || saved || store.eventsLoading)
                    if saving { ProgressView() }
                    if let saveError { Text(saveError).foregroundStyle(.red) }
                }
            }
        }
        .screenTitle("revision_plan")
        .onDisappear { request?.cancel() }
    }
}
