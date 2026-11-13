//
//  NotificationService.swift
//  sana
//

import Foundation
import UserNotifications

/// Rappels locaux avant l'échéance des tâches.
/// Réglages stockés dans UserDefaults :
///  - "reminders_enabled" (Bool) : rappels activés
///  - "reminder_lead" (Int)      : minutes avant l'échéance (15, 60 ou 1440)
@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let taskPrefix = "task-"
    private var syncTask: Task<Void, Never>?

    /// iOS garde au maximum 64 notifications locales en attente.
    private let maxScheduled = 60

    private override init() {
        super.init()
        center.delegate = self
    }

    var isAllowed: Bool {
        authorization == .authorized || authorization == .provisional
    }

    // MARK: - Autorisation

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// Affiche la demande système la première fois. Renvoie true si accordée.
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(
            options: [.alert, .sound, .badge]
        )) ?? false

        await refreshAuthorization()
        return granted
    }

    // MARK: - Planification

    /// Recalcule tous les rappels à partir de la liste de tâches.
    /// Appelée à chaque changement des tâches ou des réglages.
    func sync(tasks: [StudyTask]) {
        syncTask?.cancel()
        syncTask = Task { await perform(tasks) }
    }

    private func perform(_ tasks: [StudyTask]) async {
        await removeScheduledTasks()

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "reminders_enabled") else { return }

        await refreshAuthorization()
        guard isAllowed, !Task.isCancelled else { return }

        let lead = defaults.object(forKey: "reminder_lead") as? Int ?? 60
        let now = Date()

        let upcoming = tasks
            .filter { !$0.isDone }
            .map { ($0, $0.dueDate.addingTimeInterval(-Double(lead) * 60)) }
            .filter { $0.1 > now }
            .sorted { $0.1 < $1.1 }
            .prefix(maxScheduled)

        for (task, fireDate) in upcoming {
            if Task.isCancelled { return }

            let content = UNMutableNotificationContent()
            content.title = tr("notif_title")
            content.body = String(
                format: tr("notif_body"),
                task.title,
                task.course
            )
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: taskPrefix + task.id,
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }

    /// Supprime tous les rappels de tâches (ex. à la déconnexion).
    func clear() {
        syncTask?.cancel()
        syncTask = Task { await removeScheduledTasks() }
    }

    private func removeScheduledTasks() async {
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(taskPrefix) }

        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Notification de test dans 5 secondes (pratique pour une démonstration).
    func scheduleTest() async {
        await refreshAuthorization()
        guard isAllowed else { return }

        let content = UNMutableNotificationContent()
        content.title = tr("notif_test_title")
        content.body = tr("notif_test_body")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test-reminder",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: 5,
                repeats: false
            )
        )

        try? await center.add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Affiche aussi la notification quand l'app est au premier plan.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
