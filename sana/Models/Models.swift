//
//  Models.swift
//  sana
//
//  Created by Tekup-mac-4 on 6/11/2026.
//

import Foundation

struct StudyTask: Identifiable, Hashable {

    var id: String
    var title: String
    var details: String
    var course: String
    var dueDate: Date
    var priority: Int
    var isDone: Bool

    static var empty: StudyTask {
        StudyTask(
            id: UUID().uuidString,
            title: "",
            details: "",
            course: "General",
            dueDate: .now,
            priority: 1,
            isDone: false
        )
    }

    var asDocument: [String: Any] {
        [
            "title": title,
            "details": details,
            "course": course,
            "dueDate": dueDate,
            "priority": priority,
            "isDone": isDone
        ]
    }

    init(
        id: String,
        title: String,
        details: String,
        course: String,
        dueDate: Date,
        priority: Int,
        isDone: Bool
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.course = course
        self.dueDate = dueDate
        self.priority = priority
        self.isDone = isDone
    }
}

struct StudyCourse: Identifiable, Hashable {

    var id: String
    var name: String
    var teacher: String
    var room: String
    var weekday: Int

    var asDocument: [String: Any] {
        [
            "name": name,
            "teacher": teacher,
            "room": room,
            "weekday": weekday
        ]
    }

    static var empty: StudyCourse {
        StudyCourse(
            id: UUID().uuidString,
            name: "",
            teacher: "",
            room: "",
            weekday: 2
        )
    }
}

struct WeatherSnapshot: Decodable {

    let current: Current

    struct Current: Decodable {
        let temperature_2m: Double
        let relative_humidity_2m: Int
        let weather_code: Int
    }
}

/// Un lieu pour la météo (position de l'utilisateur ou ville par défaut).
struct Place: Equatable {

    var name: String
    var latitude: Double
    var longitude: Double

    /// Lieu utilisé quand la localisation est refusée ou indisponible.
    static let tunis = Place(
        name: "Tunis",
        latitude: 36.8065,
        longitude: 10.1815
    )
}

extension WeatherSnapshot.Current {

    /// Clé de traduction décrivant le code météo WMO d'Open-Meteo.
    var descriptionKey: String {
        switch weather_code {
        case 0: return "wx_clear"
        case 1, 2: return "wx_partly"
        case 3: return "wx_cloudy"
        case 45, 48: return "wx_fog"
        case 51, 53, 55, 56, 57: return "wx_drizzle"
        case 61, 63, 65, 66, 67: return "wx_rain"
        case 71, 73, 75, 77, 85, 86: return "wx_snow"
        case 80, 81, 82: return "wx_showers"
        case 95, 96, 99: return "wx_storm"
        default: return "wx_unknown"
        }
    }

    /// Symbole SF correspondant au code météo.
    var symbol: String {
        switch weather_code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "questionmark.circle"
        }
    }
}
