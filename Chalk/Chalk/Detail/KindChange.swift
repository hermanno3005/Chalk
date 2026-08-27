import Foundation

/// `Change kind` — the free-weight ↔ gym-bound flip, reached from the detail screen's
/// overflow (SPEC §8, §5.5).
///
/// **Each direction is one decision, with no orphans and no permanent null case.** Going
/// gym-bound asks once which machine the existing entries belong to and moves them
/// wholesale; coming back pools everything behind one confirmation that names the
/// consequence out loud. Pooling merges numbers from separate machines into one curve —
/// the pollution the model otherwise forbids — except that here you are asserting the
/// load transfers, which is what makes it legitimate.
///
/// Not offering the flip at all is rejected: a genuine misclassification would then be
/// unfixable without deleting the exercise and losing its history.
///
/// The type is the words and the counts; the writes are
/// `ExerciseDetailModel.makeGymBound(…)` and `.makeFreeWeight()`.
struct KindChange {
    let exercise: Exercise

    /// Which way the flip runs — read off the kind the exercise is now. There is no
    /// third state and nothing to choose: the item on the overflow is one verb.
    enum Direction { case toGymBound, toFreeWeight }

    var direction: Direction { exercise.isGymBound ? .toFreeWeight : .toGymBound }

    /// The machines the flip will delete. Empty going the other way — a free-weight
    /// exercise cannot have any, which is exactly why keeping them for a possible
    /// flip-back is rejected.
    var machines: [Machine] { exercise.machines ?? [] }

    /// The machines that actually hold entries — **the count the confirmation says out
    /// loud**, because it is the number of curves about to become one. A machine you
    /// made and never logged on is deleted with the rest and pools nothing.
    var loggedMachineCount: Int {
        machines.filter { !($0.entries ?? []).isEmpty }.count
    }

    var entryCount: Int { (exercise.entries ?? []).count }

    /// Whether the flip has to ask which machine the existing entries belong to.
    ///
    /// **Only where there are entries to place.** An exercise with nothing logged has
    /// nothing to orphan, and a gym-bound exercise with no machine is a state the app
    /// already has — the empty state, until the first log makes one (SPEC §5.3, §6.4).
    /// Asking for a machine there would invent a decision the flip does not need.
    var needsAMachine: Bool { direction == .toGymBound && entryCount > 0 }

    /// The confirmation's title. Going free-weight it is **the consequence, phrased as
    /// the sentence the spec puts in the user's face**: *"Bench Press has entries on 3
    /// machines. They'll merge into one curve."*
    var question: String {
        switch direction {
        case .toGymBound:
            return "Make \(exercise.name) gym-bound?"
        case .toFreeWeight:
            switch loggedMachineCount {
            case 0:
                return "Make \(exercise.name) free-weight?"
            case 1:
                // One curve does not merge with anything; saying it would is a lie about
                // the only thing this confirmation exists to say.
                return "\(exercise.name) has entries on one machine. They'll become the exercise's own curve."
            default:
                return "\(exercise.name) has entries on \(phrase(machines: loggedMachineCount)). They'll merge into one curve."
            }
        }
    }

    /// The line under the question: what is kept, what goes, and that nothing brings it
    /// back. The machines are the only thing this flip destroys, so they are named with
    /// their count in every branch that has one.
    var detail: String {
        switch direction {
        case .toGymBound:
            return "Its numbers will be kept per machine. Log a lift and name the one you are at."
        case .toFreeWeight where machines.isEmpty:
            return "It has no machines, and every entry stays exactly as it is."
        case .toFreeWeight where loggedMachineCount == 0:
            return "Nothing is logged on \(phrase(machines: machines.count)). \(machines.count == 1 ? "It is" : "They are") deleted, and this cannot be undone."
        case .toFreeWeight:
            return "Every entry is kept. \(phrase(machines: machines.count)) \(machines.count == 1 ? "is" : "are") deleted, and this cannot be undone."
        }
    }

    /// The confirming button, phrased as the kind you end up with rather than as *OK*.
    var confirmButton: String {
        direction == .toGymBound ? "Make gym-bound" : "Make free-weight"
    }

    /// The machine prompt's question — **one machine, for every entry there is**. It is
    /// asked once and there is no "some of them": splitting a history across machines
    /// after the fact is the history sheet's per-entry machine edit (SPEC §6.6).
    var prompt: String { "Which machine are these entries on?" }

    var promptDetail: String {
        "\(exercise.name) becomes gym-bound, and all \(phrase(entries: entryCount)) move to the machine you pick."
    }

    /// Counted nouns, so no sentence here says *1 machines*. Labelled rather than
    /// overloaded on the count alone: `machines` is already the collection this type
    /// reads, and a call that formats it must not look like a call that indexes it.
    private func phrase(machines count: Int) -> String {
        count == 1 ? "1 machine" : "\(count) machines"
    }

    private func phrase(entries count: Int) -> String {
        count == 1 ? "1 entry" : "\(count) entries"
    }
}
