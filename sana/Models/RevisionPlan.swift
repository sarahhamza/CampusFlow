//
//  RevisionPlan.swift
//  sana
//
//  Plan de révision généré par Gemini.
//

import Foundation

struct RevisionPlan: Codable, Equatable {

    var summary: String
    var days: [Day]

    struct Day: Codable, Identifiable, Equatable {
        /// Date au format « yyyy-MM-dd ».
        var date: String
        var sessions: [Session]

        var id: String { date }

        var totalMinutes: Int {
            sessions.reduce(0) { $0 + $1.minutes }
        }

        var parsedDate: Date? {
            RevisionPlan.dayFormatter.date(from: date)
        }
    }

    struct Session: Codable, Identifiable, Equatable {
        var course: String
        var topic: String
        var minutes: Int
        var tip: String

        var id = UUID()

        private enum CodingKeys: String, CodingKey {
            case course, topic, minutes, tip
        }
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
