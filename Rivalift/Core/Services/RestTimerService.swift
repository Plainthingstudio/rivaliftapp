import Foundation
import Observation

/// Rest timer (LOG-08, LOG-09). Stores an absolute end date instead of counting down so it
/// stays accurate in the background, after a phone call or a relaunch, and schedules a
/// local notification as a backup.
@MainActor
@Observable
final class RestTimerService {
    private(set) var endDate: Date?
    private(set) var totalDuration: TimeInterval = 0
    private(set) var exerciseName: String?

    var soundEnabled = true
    var hapticsEnabled = true

    private let notifications: NotificationService
    private var finishTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private static let endKey = "restTimer.endDate"
    private static let durationKey = "restTimer.duration"
    private static let nameKey = "restTimer.exercise"

    init(notifications: NotificationService, defaults: UserDefaults = .standard) {
        self.notifications = notifications
        self.defaults = defaults
        restore()
    }

    var isRunning: Bool {
        guard let endDate else { return false }
        return endDate > Date()
    }

    func remaining(at date: Date = Date()) -> TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(date))
    }

    func progress(at date: Date = Date()) -> Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - remaining(at: date) / totalDuration
    }

    func start(seconds: Int, nextExerciseName: String?) {
        guard seconds > 0 else { stop(); return }
        totalDuration = TimeInterval(seconds)
        exerciseName = nextExerciseName
        setEnd(Date().addingTimeInterval(totalDuration))
    }

    /// −15 s / +15 s buttons.
    func adjust(by seconds: Int) {
        guard let endDate else { return }
        let newEnd = endDate.addingTimeInterval(TimeInterval(seconds))
        if newEnd <= Date() {
            stop()
        } else {
            totalDuration = max(totalDuration + TimeInterval(seconds), newEnd.timeIntervalSinceNow)
            setEnd(newEnd)
        }
    }

    func skip() { stop() }

    func stop() {
        finishTask?.cancel()
        endDate = nil
        totalDuration = 0
        notifications.cancelRestTimer()
        persist()
    }

    private func setEnd(_ date: Date) {
        endDate = date
        notifications.scheduleRestTimer(at: date, exerciseName: exerciseName, sound: soundEnabled)
        persist()
        finishTask?.cancel()
        finishTask = Task { [weak self] in
            let delay = date.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled, let self, self.endDate == date else { return }
            Haptics.restFinished(sound: self.soundEnabled, vibrate: self.hapticsEnabled)
            self.endDate = nil
            self.persist()
        }
    }

    private func persist() {
        if let endDate {
            defaults.set(endDate, forKey: Self.endKey)
            defaults.set(totalDuration, forKey: Self.durationKey)
            defaults.set(exerciseName, forKey: Self.nameKey)
        } else {
            defaults.removeObject(forKey: Self.endKey)
        }
    }

    private func restore() {
        guard let saved = defaults.object(forKey: Self.endKey) as? Date, saved > Date() else { return }
        totalDuration = defaults.double(forKey: Self.durationKey)
        exerciseName = defaults.string(forKey: Self.nameKey)
        setEnd(saved)
    }
}
