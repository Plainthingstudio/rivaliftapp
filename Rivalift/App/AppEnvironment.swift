import Foundation
import Observation
import SwiftData

enum AppTab: Hashable {
    case home, history, leagues, profile
}

/// Dependency container shared through the SwiftUI environment. Views talk to stores and
/// repositories from here; they never touch SwiftData or the network directly (section 9).
@MainActor
@Observable
final class AppEnvironment {
    let container: ModelContainer
    let exercises: ExerciseRepository
    let templates: TemplateRepository
    let sessions: SessionRepository
    let settingsRepository: SettingsRepository
    let notifications: NotificationService
    let restTimer: RestTimerService
    let sync: SyncService
    let workout: WorkoutStore

    private(set) var settings: UserSettings

    var selectedTab: AppTab = .home
    /// Bumped after any data change so list screens can reload.
    private(set) var dataVersion = 0
    var seedError: String?

    init(inMemory: Bool = false) {
        let container = PersistenceController.makeContainer(inMemory: inMemory)
        let context = container.mainContext

        var seedError: String?
        do {
            try SeedLoader.seedIfNeeded(context: context)
        } catch {
            seedError = error.localizedDescription
        }

        let sessions = SessionRepository(context: context)
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let settingsRepository = SettingsRepository(context: context)
        let notifications = NotificationService()
        let restTimer = RestTimerService(notifications: notifications)
        let settings = settingsRepository.current()
        restTimer.soundEnabled = settings.restSoundEnabled
        restTimer.hapticsEnabled = settings.restHapticsEnabled

        self.container = container
        self.exercises = exercises
        self.templates = templates
        self.sessions = sessions
        self.settingsRepository = settingsRepository
        self.notifications = notifications
        self.restTimer = restTimer
        self.sync = SyncService(context: context)
        self.settings = settings
        self.seedError = seedError
        self.workout = WorkoutStore(
            sessions: sessions,
            exercises: exercises,
            templates: templates,
            restTimer: restTimer,
            notifications: notifications,
            settings: settings
        )

        workout.onDataChange = { [weak self] in self?.dataDidChange() }
        workout.restoreActiveSession()
    }

    var unit: WeightUnit { settings.unit }

    func dataDidChange() {
        dataVersion &+= 1
    }

    func saveSettings() {
        restTimer.soundEnabled = settings.restSoundEnabled
        restTimer.hapticsEnabled = settings.restHapticsEnabled
        settingsRepository.save()
        dataDidChange()
    }

    /// Weekly progress for Home and History headers (PROG-06).
    func weekProgress(for date: Date = Date()) -> WeekProgress {
        let calendar = WeekCalendar()
        let start = calendar.weekStart(for: date)
        let end = calendar.weekEnd(for: date)
        let thisWeek = sessions.completedSessions(from: start, to: end)
        let trainedDays = Set(thisWeek.map { calendar.localDateString(for: $0.startedAt) })

        var perWeek: [Date: Int] = [:]
        for session in sessions.completedSessions() {
            perWeek[calendar.weekStart(for: session.startedAt), default: 0] += 1
        }
        let target = settings.effectiveWeeklyTarget(at: date)
        let streak = calendar.streak(before: date, sessionsPerWeek: perWeek, target: target)
        let metNow = thisWeek.count >= target
        return WeekProgress(
            days: calendar.days(ofWeekContaining: date),
            trainedDays: trainedDays,
            sessions: thisWeek.count,
            target: target,
            streakWeeks: streak + (metNow ? 1 : 0)
        )
    }
}

struct WeekProgress {
    var days: [Date]
    var trainedDays: Set<String>
    var sessions: Int
    var target: Int
    /// Consecutive weeks meeting the target, including this week once it is met.
    var streakWeeks: Int
}
