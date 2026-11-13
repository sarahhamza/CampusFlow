import SwiftUI

/// Firestore stores weekdays using Calendar's Sunday = 1 convention.
enum CourseWeekday {
    static let ordered = [2, 3, 4, 5, 6, 7, 1]
    static func key(for day: Int) -> String {
        let keys = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        return (1...7).contains(day) ? keys[day - 1] : "weekday"
    }
}

struct CourseOverviewCard: View {
    let courses: [StudyCourse]
    let loading: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var days: Int { Set(courses.map(\.weekday).filter { (1...7).contains($0) }).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(tr("courses_overview"), systemImage: "books.vertical.fill")
                .font(.subheadline.weight(.semibold))
            Text(tr("courses_momentum")).font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            if loading {
                ProgressView(tr("loading")).tint(.white)
            } else {
                HStack(alignment: .top, spacing: 20) {
                    metric(courses.count, key: "courses")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 44).accessibilityHidden(true)
                    metric(days, key: "courses_study_days")
                }
            }
        }
        .padding(24).foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().stroke(.white.opacity(0.09), lineWidth: 26)
                    .frame(width: 150, height: 150).offset(x: 55, y: -65)
            }.clipShape(RoundedRectangle(cornerRadius: 26))
        }
        .shadow(color: .indigo.opacity(0.14), radius: 12, y: 6)
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: courses)
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

struct CourseDayFilter: View {
    @Binding var selection: Int
    @Namespace private var highlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach([0] + CourseWeekday.ordered, id: \.self) { day in
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                            selection = day
                        }
                    } label: {
                        Text(tr(day == 0 ? "all" : CourseWeekday.key(for: day)))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).frame(minHeight: 44)
                            .foregroundStyle(selection == day ? Color.white : Color.primary)
                            .background {
                                if selection == day {
                                    Capsule().fill(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                                        .matchedGeometryEffect(id: "courseDay", in: highlight)
                                } else {
                                    Capsule().fill(.indigo.opacity(0.07))
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == day ? [.isSelected] : [])
                }
            }.padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tr("weekday"))
    }
}

struct CourseCard: View {
    let course: StudyCourse
    @Environment(\.locale) private var locale
    private var accent: Color {
        let seed = course.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return seed.isMultiple(of: 2) ? .indigo : .purple
    }
    private var teacher: String {
        course.teacher.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var room: String {
        course.room.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Text(String(course.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased(with: locale))
                    .font(.title2.bold()).foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(LinearGradient(colors: [accent, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.name).font(.headline).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(teacher.isEmpty ? tr("courses_teacher_missing") : teacher, systemImage: "person")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { roomLabel; Spacer(minLength: 8); dayBadge }
                VStack(alignment: .leading, spacing: 10) { roomLabel; dayBadge }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(accent.opacity(0.13), lineWidth: 1) }
        .shadow(color: .indigo.opacity(0.04), radius: 8, y: 4)
    }

    private var roomLabel: some View {
        Label(room.isEmpty ? tr("courses_room_missing") : room, systemImage: "door.left.hand.open")
            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var dayBadge: some View {
        Label(tr(CourseWeekday.key(for: course.weekday)), systemImage: "calendar")
            .font(.caption.weight(.semibold)).foregroundStyle(accent)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(accent.opacity(0.09), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}
