import Foundation
import SwiftData

/// The v1 schema. `VersionedSchema` carries the version, so no entity holds a
/// `schemaVersion` attribute (SPEC §3).
enum ChalkSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Exercise.self, Entry.self, Gym.self, Machine.self, ExerciseGroup.self]
    }
}

/// One schema, so no stages. It exists from day one so that adding a stage later is an
/// edit rather than a retrofit.
enum ChalkMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ChalkSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
