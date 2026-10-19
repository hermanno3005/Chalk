import Foundation
import SwiftData

/// A lift you train, or an erg, held in your library — **an erg is an `Exercise` whose
/// `unit` is set** (ADR-0008). Every repair (merge, move, kind change and the deletes
/// they end in) carries ergs because they are this same type.
///
/// Deleting one cascades to its entries and its machines — and through the machines,
/// to their entries (SPEC §3).
@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    /// `freeWeight` on a lift is transferable on an erg (`ExerciseKind`).
    var kind: String = ExerciseKind.freeWeight.rawValue
    /// `nil` means Ungrouped. **Only ever a group of this row's own half** (SPEC §3,
    /// invariant 10).
    var group: ExerciseGroup?
    @Relationship(deleteRule: .cascade, inverse: \Entry.exercise)
    var entries: [Entry]? = []
    @Relationship(deleteRule: .cascade, inverse: \Machine.exercise)
    var machines: [Machine]? = []

    /// The raw value of an erg's `ErgUnit`; nil on every lift, which is what makes it a
    /// lift. **Set at create, never cleared, and changed only while the erg has no
    /// entries** (SPEC §3, invariant 9): a change after that would reinterpret every
    /// number logged.
    var unit: String?

    /// This exercise's strength goal while it is free-weight — **all three set, or no
    /// goal at all** (ADR-0004). Read and written through `GoalScope`, never directly by a
    /// screen.
    ///
    /// **A row's goal fields are its own half's** (SPEC §3, invariant 11): a lift's
    /// endurance goal fields stay nil, and an erg's strength ones do. **Every goal field is
    /// nil while the row is gym-bound**, both halves' alike — its goals live on its
    /// machines (invariant 8). `goalSetAt` is shared by both halves' goals, since a row is
    /// one half by construction.
    var goalReps: Int?
    var goalWeight: Double?
    var goalSetAt: Date?

    /// This erg's endurance goal while it is transferable — a point on a zone line:
    /// **zone, duration, intensity and (on a speed erg) incline all set with `goalSetAt`,
    /// or no goal at all** (ADR-0007). Read and written through `GoalScope`.
    ///
    /// The zone, 1…5 — never a bpm, so the goal follows the boundaries when they move.
    var goalZone: Int?
    /// Whole seconds.
    var goalDuration: Int?
    /// In the erg's unit, compared in whole steps (`ErgUnit.steps`).
    var goalIntensity: Double?
    /// Percent, on a speed erg only; nil otherwise.
    var goalIncline: Double?

    /// Whether this exercise's load transfers between gyms — the one question the whole
    /// second shape hangs off (SPEC §5.3, §6.4, §7.3). Read the same way in both halves.
    ///
    /// The kind is stored as its `rawValue` to keep the schema CloudKit-shaped
    /// (ADR-0001), so the comparison lives here once rather than at every screen that
    /// asks.
    var isGymBound: Bool { kind == ExerciseKind.gymBound.rawValue }

    /// This erg's unit, or nil on a lift.
    var ergUnit: ErgUnit? { unit.flatMap(ErgUnit.init(rawValue:)) }

    /// Whether this row is an erg: it speaks a unit.
    var isErg: Bool { unit != nil }

    init(
        id: UUID = UUID(),
        name: String = "",
        kind: ExerciseKind = .freeWeight,
        group: ExerciseGroup? = nil,
        unit: ErgUnit? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind.rawValue
        self.group = group
        self.unit = unit?.rawValue
        self.entries = []
        self.machines = []
    }
}
