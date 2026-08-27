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

    /// What this machine is called on screen: its label, or the make when it has no
    /// label of its own, or `Unlabelled` when it has neither.
    ///
    /// A machine is often just *the leg press by the window* with nothing written on it,
    /// and the default machine at a gym is exactly the one that stays unnamed — so the
    /// fallback is a real word rather than a blank row (SPEC §7.5).
    var name: String {
        [label, manufacturer]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? Self.unlabelled
    }

    /// The one line the app says a machine in, everywhere it says one: `label · gym`
    /// (SPEC §5.3, §6.4).
    ///
    /// A gym-less machine renders as its name with no suffix — that state is never
    /// intentionally produced, but it can arrive from a gym deletion and it still
    /// derives normally (SPEC §3, invariant 3).
    var caption: String {
        guard let gymName = gym?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !gymName.isEmpty
        else { return name }
        return "\(name) · \(gymName)"
    }

    /// When you last lifted on this machine, `nil` for one you have never logged on.
    var lastLogged: Date? {
        (entries ?? []).filter(\.isALift).map(\.date).max()
    }

    static let unlabelled = "Unlabelled"

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
