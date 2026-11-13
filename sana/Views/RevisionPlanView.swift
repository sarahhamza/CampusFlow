//
//  RevisionPlanView.swift
//  sana
//
//  Écran « Générer un plan de révision » (Gemini).
//

import SwiftUI

struct RevisionPlanView: View {

    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var preferences: Preferences
    @StateObject private var service = RevisionPlanService()

    @State private var days = 7
    @State private var hoursPerDay = 2

    private var pendingTasks: [StudyTask] {
        store.tasks.filter { !$0.isDone }
    }

    /// Il faut au moins une matière ou une tâche pour que le plan ait un sens.
    private var hasInput: Bool {
        !pendingTasks.isEmpty || !store.courses.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                options

                if !hasInput {
                    ContentUnavailableView(
                        tr("revision_empty_input"),
                        systemImage: "tray",
                        description: Text(tr("revision_empty_input_hint"))
                    )
                }

                generateButton

                if let error = service.error {
                    errorCard(error)
                }

                if service.loading {
                    ProgressView(tr("revision_generating"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let plan = service.plan {
                    planContent(plan)
                }
            }
            .padding()
        }
        .screenTitle("revision_plan")
        .animation(.smooth, value: service.plan)
        .animation(.smooth, value: service.loading)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(tr("revision_plan"), systemImage: "sparkles")
                .font(.headline)

            Text(tr("revision_plan_hint"))
                .font(.subheadline)
                .opacity(0.9)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [.indigo, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("revision_horizon")).font(.subheadline.bold())

            Picker(tr("revision_horizon"), selection: $days) {
                ForEach([7, 14, 30], id: \.self) { value in
                    Text(String(format: tr("revision_days_fmt"), value))
                        .tag(value)
                }
            }
            .pickerStyle(.segmented)

            Stepper(
                value: $hoursPerDay,
                in: 1...8
            ) {
                Text(String(format: tr("revision_hours_fmt"), hoursPerDay))
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .disabled(service.loading)
    }

    private var generateButton: some View {
        Button {
            Task {
                await service.generate(
                    RevisionPlanInput(
                        tasks: store.tasks,
                        events: store.events,
                        courses: store.courses,
                        days: days,
                        hoursPerDay: hoursPerDay,
                        language: preferences.language
                    )
                )
            }
        } label: {
            Label(
                tr(service.plan == nil
                   ? "revision_generate"
                   : "revision_regenerate"),
                systemImage: "wand.and.stars"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(service.loading || !hasInput)
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.red.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }

    @ViewBuilder
    private func planContent(_ plan: RevisionPlan) -> some View {
        if !plan.summary.isEmpty {
            Text(plan.summary)
                .font(.callout)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.indigo.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 16)
                )
        }

        if plan.days.isEmpty {
            ContentUnavailableView(
                tr("gemini_bad_response"),
                systemImage: "exclamationmark.magnifyingglass"
            )
        } else {
            ForEach(plan.days) { day in
                RevisionDayCard(day: day)
            }
        }
    }
}

struct RevisionDayCard: View {

    let day: RevisionPlan.Day

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let date = day.parsedDate {
                    Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.headline)
                } else {
                    Text(day.date).font(.headline)
                }

                Spacer()

                Text(String(format: tr("revision_min_fmt"), day.totalMinutes))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.indigo.opacity(0.15), in: Capsule())
            }

            ForEach(day.sessions) { session in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(session.course)
                            .font(.subheadline.bold())
                            .foregroundStyle(.indigo)

                        Spacer()

                        Text(String(format: tr("revision_min_fmt"), session.minutes))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(session.topic)

                    if !session.tip.isEmpty {
                        Label(session.tip, systemImage: "lightbulb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if session.id != day.sessions.last?.id {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
