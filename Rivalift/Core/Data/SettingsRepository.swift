import Foundation
import SwiftData

@MainActor
final class SettingsRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Returns the single settings row, creating it if needed and merging duplicates.
    func current() -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>(sortBy: [SortDescriptor(\.createdAt)])
        let rows = (try? context.fetch(descriptor)) ?? []
        if let first = rows.first {
            for duplicate in rows.dropFirst() {
                if duplicate.onboardingDone { first.onboardingDone = true }
                context.delete(duplicate)
            }
            first.applyPendingTargetIfDue()
            try? context.save()
            return first
        }
        let settings = UserSettings()
        settings.unit = Locale.current.measurementSystem == .us ? .lb : .kg
        context.insert(settings)
        try? context.save()
        return settings
    }

    func save() { try? context.save() }
}
