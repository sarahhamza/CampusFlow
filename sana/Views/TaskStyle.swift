import SwiftUI

/// Uses the same indigo–purple gradient as the dashboard's focus card.
struct TaskOverviewCard: View {
    let total: Int
    let completed: Int
    let loading: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double { total == 0 ? 0 : Double(completed) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(tr("tasks_overview"), systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
            Text(tr("tasks_momentum"))
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            if loading {
                ProgressView(tr("loading")).tint(.white)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    metric(total - completed, key: "pending")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 44).accessibilityHidden(true)
                    metric(completed, key: "completed")
                }
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress)
                        .tint(.white)
                        .accessibilityLabel(tr("tasks_progress"))
                    Text("\(completed) / \(total) \(tr("completed"))")
                        .font(.caption.weight(.medium))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().stroke(.white.opacity(0.09), lineWidth: 26)
                    .frame(width: 150, height: 150).offset(x: 55, y: -65)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
        }
        .shadow(color: .indigo.opacity(0.14), radius: 12, y: 6)
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: completed)
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: total)
    }

    private func metric(_ count: Int, key: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(count, format: .number)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
            Text(tr(key)).font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct TaskFilterBar: View {
    @Binding var selection: Int
    let counts: [Int]
    @Namespace private var highlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    private let keys = ["all", "pending", "completed"]

    var body: some View {
        // Vertical controls keep translated labels readable at accessibility sizes.
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 4) { options }
            } else {
                HStack(spacing: 4) { options }
            }
        }
        .padding(5)
        .background(.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tr("status"))
    }

    private var options: some View {
        ForEach(keys.indices, id: \.self) { index in
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                    selection = index
                }
            } label: {
                VStack(spacing: 4) {
                    Text(tr(keys[index])).font(.caption.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(counts[index], format: .number)
                        .font(.caption2.bold()).monospacedDigit()
                        .contentTransition(.numericText())
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .foregroundStyle(selection == index ? Color.white : Color.primary)
                .background {
                    if selection == index {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                            .matchedGeometryEffect(id: "taskFilter", in: highlight)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr(keys[index]))
            .accessibilityValue(Text(counts[index], format: .number))
            .accessibilityAddTraits(selection == index ? [.isSelected] : [])
        }
    }
}

/// Shared by Tasks, the dashboard, and task deadlines in Calendar.
struct TaskRow: View {
    let task: StudyTask
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    private var accent: Color {
        task.isDone ? .teal : (task.priority == 3 ? .purple : .indigo)
    }
    private var priorityKey: String {
        switch task.priority {
        case 3: return "high"
        case 2: return "medium"
        default: return "low"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "text.badge.checkmark")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title).font(.headline)
                        .strikethrough(task.isDone, color: .secondary)
                        .foregroundStyle(task.isDone ? Color.secondary : Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(task.course).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if !task.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(task.details).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { dateLabel; Spacer(minLength: 8); statusBadge }
                VStack(alignment: .leading, spacing: 8) { dateLabel; statusBadge }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).strokeBorder(accent.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: .indigo.opacity(0.04), radius: 8, y: 4)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: task.isDone)
    }

    private var dateLabel: some View {
        Label {
            Text(task.dueDate, format: .dateTime.day().month(.abbreviated).locale(locale))
        } icon: {
            Image(systemName: "calendar")
        }
        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
        .fixedSize()
        .accessibilityLabel(Text(tr("deadline")) + Text(": ") + Text(task.dueDate, format: .dateTime.day().month(.wide).year().locale(locale)))
    }

    private var statusBadge: some View {
        Label(tr(task.isDone ? "completed" : priorityKey), systemImage: task.isDone ? "checkmark" : "flag.fill")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(accent)
            .background(accent.opacity(0.09), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(task.isDone ? tr("completed") : "\(tr("priority")): \(tr(priorityKey))")
    }
}
