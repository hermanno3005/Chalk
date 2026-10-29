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

    /// This machine's strength goal — **all three set, or no goal at all** (ADR-0004).
    /// Rides the machine: it dies with it and survives its gym's deletion. Read and
    /// written through `GoalScope`, never directly by a screen.
    ///
    /// **A row's goal fields are its own half's** (SPEC §3, invariant 11): a lift's
    /// machine leaves the endurance goal fields nil, and an erg's machine the strength
    /// ones. `goalSetAt` is shared by both halves' goals, so *the most recently set goal
    /// wins* reads one field.
    var goalReps: Int?
    var goalWeight: Double?
    var goalSetAt: Date?

    /// This machine's endurance goal, as on a transferable erg (`Exercise.goalZone`):
    /// zone, duration, intensity and (on a speed erg) incline all set with `goalSetAt`,
    /// or no goal at all (ADR-0007).
    var goalZone: Int?
    var goalDuration: Int?
    var goalIntensity: Double?
    var goalIncline: Double?

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
        gymName.map { "\(name) · \($0)" } ?? name
    }

    /// `caption` as VoiceOver says it: `Technogym Run at Urban Gym`.
    var spokenCaption: String {
        gymName.map { "\(name) at \($0)" } ?? name
    }

    /// The gym's name as the caption reads it, nil where there is none to read.
    private var gymName: String? {
        guard let gymName = gym?.name.trimmingCharacters(in: .whitespacesAndNewlines), !gymName.isEmpty else { return nil }
        return gymName
    }

    /// When you last logged on this machine, `nil` for one you have never logged on: its
    /// latest lift, or on an erg's machine its latest valid interval — its own half's by
    /// construction (SPEC §13.12).
    var lastLogged: Date? {
        (entries ?? []).filter { $0.isALift || $0.isAnInterval }.map(\.date).max()
    }

    static let unlabelled = "Unlabelled"

    /// The optional one-field answer to `Name this machine`, normalised: **a blank name
    /// is no name at all**, and renders as `Unlabelled` rather than as an empty row.
    ///
    /// The rule lives here rather than at each door that asks — the log sheet's
    /// `New machine here` (SPEC §6.4) and `Change kind`'s machine prompt (§8) — so the
    /// two cannot drift.
    static func label(from name: String?) -> String? {
        let label = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (label?.isEmpty == false) ? label : nil
    }

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
