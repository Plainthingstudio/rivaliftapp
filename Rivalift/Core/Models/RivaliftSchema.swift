import Foundation
import SwiftData

/// Versioned schema so future model changes ship with tested migrations (section 14.2).
enum RivaliftSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SessionExercise.self,
            SetEntry.self,
            PersonalRecord.self,
            SyncQueueItem.self,
            UserSettings.self,
        ]
    }
}

enum RivaliftMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [RivaliftSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum PersistenceController {
    static let cloudKitContainerID = "iCloud.app.rivalift.ios"

    /// - Parameter inMemory: used by tests, previews and UI tests.
    @MainActor
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: RivaliftSchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerID))
        }
        do {
            return try ModelContainer(for: schema, migrationPlan: RivaliftMigrationPlan.self, configurations: configuration)
        } catch {
            // Fall back to a local-only store (e.g. iCloud misconfigured) rather than crashing.
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, migrationPlan: RivaliftMigrationPlan.self, configurations: local)
            } catch {
                fatalError("Unable to create ModelContainer: \(error)")
            }
        }
    }
}
