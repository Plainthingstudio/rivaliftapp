import Foundation
import SwiftData

/// What Home shows: today's workout from the plan, or the user's own workouts.
enum HomeMode: String, Sendable {
    case plan, custom
}

/// Single-row settings. Duplicate rows (e.g. from two devices syncing through iCloud)
/// are merged in `SettingsRepository`.
@Model
final class UserSettings {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var displayName: String = ""
    /// Profile photo as a downscaled JPEG (AUTH-04); nil shows the default avatar.
    @Attribute(.externalStorage) var avatarImageData: Data?
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
    /// Onboarding answers used to recommend a built-in program (`PlanRecommender`).
    var goalRaw: String = TrainingGoal.fitness.rawValue
    var experienceRaw: String = ExperienceLevel.beginner.rawValue
    /// Program name from templates.json, e.g. "Full Body 3×"; empty until onboarding ends.
    var planProgram: String = ""
    /// When the current plan started ("Week 2 of 8"); nil until Home first shows the plan.
    var planStartedAt: Date?
    /// Home mode: `HomeMode` raw value.
    var homeModeRaw: String = HomeMode.plan.rawValue
    /// Weekly streak the user committed to during onboarding (0 = none).
    var streakGoalWeeks: Int = 0
    /// 0 = not started; then the step reached; persisted so closing the app keeps choices (AUTH-05).
    var onboardingStep: Int = 0
    var onboardingDone: Bool = false
    var hasAskedNotificationPermission: Bool = false

    init() {}

    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue }
    }

    var goal: TrainingGoal {
        get { TrainingGoal(rawValue: goalRaw) ?? .fitness }
        set { goalRaw = newValue.rawValue }
    }

    var homeMode: HomeMode {
        get { HomeMode(rawValue: homeModeRaw) ?? .plan }
        set { homeModeRaw = newValue.rawValue }
    }

    var experience: ExperienceLevel {
        get { ExperienceLevel(rawValue: experienceRaw) ?? .beginner }
        set { experienceRaw = newValue.rawValue }
    }

    /// ISO weekdays (1 = Monday) the user plans to train.
    var trainingWeekdays: Set<Int> {
        get { Set(reminderWeekdaysRaw.split(separator: ",").compactMap { Int($0) }) }
        set { reminderWeekdaysRaw = newValue.sorted().map(String.init).joined(separator: ",") }
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
