import Foundation
import SwiftData

/// Single-row settings. Duplicate rows (e.g. from two devices syncing through iCloud)
/// are merged in `SettingsRepository`.
@Model
final class UserSettings {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var displayName: String = ""
    var unitRaw: String = WeightUnit.kg.rawValue
    var weeklyTarget: Int = 3
    /// Target changes apply from the next week (section 6.1, T).
    var pendingWeeklyTarget: Int?
    var pendingTargetEffectiveFrom: Date?
    var compoundRestSec: Int = 150
    var isolationRestSec: Int = 90
    var restSoundEnabled: Bool = true
    var restHapticsEnabled: Bool = true
    var notifyRestTimer: Bool = true
    var notifyWorkoutReminder: Bool = true
    var notifyOvertaken: Bool = true
    var notifyAlmostRankUp: Bool = true
    var notifyLeagueResults: Bool = true
    var notifyNewMember: Bool = true
    var reminderHour: Int = 18
    /// ISO weekdays (1 = Monday) for workout reminders, comma separated.
    var reminderWeekdaysRaw: String = ""
    /// 0 = not started; 1…3 = step reached; persisted so closing the app keeps choices (AUTH-05).
    var onboardingStep: Int = 0
    var onboardingDone: Bool = false
    var hasAskedNotificationPermission: Bool = false

    init() {}

    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue }
    }

    /// Promotes a pending target once its week has started.
    func applyPendingTargetIfDue(now: Date = Date()) {
        guard let pending = pendingWeeklyTarget, let from = pendingTargetEffectiveFrom, now >= from else { return }
        weeklyTarget = pending
        pendingWeeklyTarget = nil
        pendingTargetEffectiveFrom = nil
    }

    /// Weekly target in effect at `date`.
    func effectiveWeeklyTarget(at date: Date = Date()) -> Int {
        if let pending = pendingWeeklyTarget, let from = pendingTargetEffectiveFrom, date >= from {
            return pending
        }
        return weeklyTarget
    }
}
