import Foundation
import UserNotifications

/// Local notifications: rest timer (NOT-01), stale session nudge (section 14.1).
/// Permission is requested after the first finished session, not during onboarding (section 10).
@MainActor
final class NotificationService {
    static let restTimerID = "rest-timer"
    static let staleSessionID = "stale-session"

    private let center = UNUserNotificationCenter.current()

    nonisolated func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    nonisolated func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleRestTimer(at date: Date, exerciseName: String?, sound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Rest's over")
        if let exerciseName {
            content.body = String(localized: "Next set of \(exerciseName).")
        } else {
            content.body = String(localized: "Time for your next set.")
        }
        content.sound = sound ? .default : nil
        schedule(id: Self.restTimerID, content: content, at: date)
    }

    func cancelRestTimer() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.restTimerID])
    }

    /// After 3 hours without a completed set, remind the user to finish the workout.
    func scheduleStaleSessionReminder(after lastActivity: Date) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Still working out?")
        content.body = String(localized: "Your workout is still running. Finish it to save your progress.")
        content.sound = .default
        schedule(id: Self.staleSessionID, content: content, at: lastActivity.addingTimeInterval(3 * 3600))
    }

    func cancelStaleSessionReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.staleSessionID])
    }

    /// Replaces all pending workout reminders (NOT-02). One-shot requests, so a day can be
    /// skipped once the user trained; `AppEnvironment.refreshWorkoutReminders` keeps them current.
    func scheduleWorkoutReminders(at dates: [Date]) {
        center.removePendingNotificationRequests(withIdentifiers: (0..<Self.maxWorkoutReminders).map { "\(Self.workoutReminderPrefix)\($0)" })
        for (index, date) in dates.prefix(Self.maxWorkoutReminders).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Time to train")
            // ponytail: PRD copy mentions "your crew"; switch to it once leagues are live (M5).
            content.body = String(localized: "Today is one of your training days. Start a workout to stay on track.")
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: "\(Self.workoutReminderPrefix)\(index)", content: content, trigger: trigger))
        }
    }

    static let workoutReminderPrefix = "workout-reminder-"
    static let maxWorkoutReminders = 14

    private func schedule(id: String, content: UNNotificationContent, at date: Date) {
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
