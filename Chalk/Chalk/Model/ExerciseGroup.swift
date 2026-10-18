import Foundation
import SwiftData

/// A user-owned, ordered bucket an exercise or erg may sit in. Named `ExerciseGroup` to
/// leave SwiftUI's `Group` view alone.
///
/// `sortIndex` is a real field rather than array position: relationship arrays are not
/// order-preserving when mirrored. Deleting a group only nullifies — its exercises fall
/// back to Ungrouped (SPEC §3).
@Model
final class ExerciseGroup {
    var id: UUID = UUID()
    var name: String = ""
    var sortIndex: Int = 0
    /// The raw value of the `Half` this group shelves, strength by default — every group
    /// written before endurance existed is strength's. A group has no unit, so unlike an
    /// exercise it needs this field to know its half (ADR-0008).
    ///
    /// **An exercise or erg sits only in a group of its own half** (SPEC §3, invariant
    /// 10): a lift in a group whose `half` is strength, an erg in one whose `half` is
    /// endurance. Group fetches filter on this field; the relationship does not need to.
    var half: String = Half.strength.rawValue
    @Relationship(deleteRule: .nullify, inverse: \Exercise.group)
    var exercises: [Exercise]? = []

    init(id: UUID = UUID(), name: String = "", sortIndex: Int = 0, half: Half = .strength) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.half = half.rawValue
        self.exercises = []
    }
}
