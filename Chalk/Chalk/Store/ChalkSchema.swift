import Foundation
import SwiftData

/// The v1 schema. `VersionedSchema` carries the version, so no entity holds a
/// `schemaVersion` attribute (SPEC §3).
///
/// **2.0.0 is bumped in place**, not frozen as a V1 copy beside a V2: goals added three
/// optional fields to `Exercise` and `Machine` and nothing else, and SwiftData infers
/// that additive migration with no stage listed (ADR-0004). **3.0.0 is bumped in place
/// the same way**: endurance adds fifteen optional or defaulted attributes to the five
/// entities and no entity, relationship or delete rule (ADR-0008). `SchemaMigrationTests`
/// is what proves both, against copies of 1.0.0 and 2.0.0 as the app wrote them.
enum ChalkSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

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
