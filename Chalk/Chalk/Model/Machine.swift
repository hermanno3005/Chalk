import Foundation
import SwiftData

/// A gym-bound exercise at a particular gym, optionally distinguished by manufacturer
/// or label. One gym may hold several for the same exercise; their numbers are separate.
///
/// `gym == nil` is representable but never intentionally produced — it can only arise
/// from a gym deletion (SPEC §3).
@Model
final class Machine {
    var id: UUID = UUID()
    /// Editable later; never a key.
    var manufacturer: String?
    var label: String?
    var exercise: Exercise?
    var gym: Gym?
    @Relationship(deleteRule: .cascade, inverse: \Entry.machine)
    var entries: [Entry]? = []

    init(
        id: UUID = UUID(),
        manufacturer: String? = nil,
        label: String? = nil,
        exercise: Exercise? = nil,
        gym: Gym? = nil
    ) {
        self.id = id
        self.manufacturer = manufacturer
        self.label = label
        self.exercise = exercise
        self.gym = gym
        self.entries = []
    }
}
