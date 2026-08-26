import Foundation
import SwiftData

/// One logged performance of an exercise: a rep count, a weight, and the moment it
/// was logged. The only thing Chalk stores about your lifting.
///
/// `reps >= 1` and `weight > 0` are app-level guards, not schema rules — every
/// attribute here is defaulted so the schema stays CloudKit-shaped (ADR-0001).
/// An entry with a nil `exercise` is treated as non-existent (SPEC §3).
@Model
final class Entry {
    var id: UUID = UUID()
    /// >= 1, no upper bound.
    var reps: Int = 0
    /// Kilograms, always. > 0.
    var weight: Double = 0
    /// Immutable after creation.
    var date: Date = Date.now
    /// Always set in practice.
    var exercise: Exercise?
    /// Gym-bound exercises only.
    var machine: Machine?

    init(
        id: UUID = UUID(),
        reps: Int = 0,
        weight: Double = 0,
        date: Date = .now,
        exercise: Exercise? = nil,
        machine: Machine? = nil
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.date = date
        self.exercise = exercise
        self.machine = machine
    }
}
