import Foundation
import SwiftData

/// A movement you train, held in your library.
///
/// Deleting one cascades to its entries and its machines — and through the machines,
/// to their entries (SPEC §3).
@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var kind: String = ExerciseKind.freeWeight.rawValue
    /// `nil` means Ungrouped.
    var group: ExerciseGroup?
    @Relationship(deleteRule: .cascade, inverse: \Entry.exercise)
    var entries: [Entry]? = []
    @Relationship(deleteRule: .cascade, inverse: \Machine.exercise)
    var machines: [Machine]? = []

    /// Whether this exercise's load transfers between gyms — the one question the whole
    /// second shape hangs off (SPEC §5.3, §6.4, §7.3).
    ///
    /// The kind is stored as its `rawValue` to keep the schema CloudKit-shaped
    /// (ADR-0001), so the comparison lives here once rather than at every screen that
    /// asks.
    var isGymBound: Bool { kind == ExerciseKind.gymBound.rawValue }

    init(
        id: UUID = UUID(),
        name: String = "",
        kind: ExerciseKind = .freeWeight,
        group: ExerciseGroup? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind.rawValue
        self.group = group
        self.entries = []
        self.machines = []
    }
}
