import Foundation

/// `Merge into…` — the repair for a **split machine** (SPEC §7.5).
///
/// The failure it repairs is late relabelling: ten entries on the unlabelled default
/// machine, and a month later you notice the stack says *Hammer Strength* and create a
/// machine for it. Same physical machine, two curves, and the number you trust has
/// silently halved. No creation-time warning can catch that, which is why — unlike gyms
/// — machine creation gets no near-name warning and this verb exists instead.
///
/// The type is the picker's rule and the confirmation's words; the write is
/// `GymsModel.merge(_:into:)`.
struct MachineMerge {

    /// The machine the entries leave, and which is hard-deleted afterwards.
    let loser: Machine

    /// The machine they land on — the sibling that survives.
    let sibling: Machine

    /// The machines `Merge into…` offers for `machine`: **same gym, same exercise
    /// siblings only**, most recently logged first. Merging across gyms is incoherent by
    /// construction — a gym-bound exercise's load does not transfer — and merging across
    /// exercises is not a repair at all.
    ///
    /// **Empty means the verb is absent from the row, not disabled.** A dead verb on a
    /// rare admin screen is a puzzle.
    ///
    /// A machine with no gym or no exercise has no sibling set: the verb only lives on a
    /// row inside a gym, so such a machine has no row to draw it on (SPEC §3).
    static func targets(for machine: Machine) -> [Machine] {
        guard let gym = machine.gym, let exercise = machine.exercise else { return [] }
        let siblings = (exercise.machines ?? []).filter {
            $0 !== machine && $0.gym?.id == gym.id
        }
        return MachineScope.byRecency(siblings)
    }

    /// How many entries the merge moves — **every one the loser holds**, zeroed rows
    /// included. Merge is all-or-nothing: re-pointing only some of them is the history
    /// sheet's per-entry machine edit (SPEC §6.6).
    var movingCount: Int { (loser.entries ?? []).count }

    /// What the sibling holds once they land.
    var resultingCount: Int { (sibling.entries ?? []).count + movingCount }

    /// The confirmation's question — **phrased as the outcome and carrying the count**:
    /// *"Move 8 entries to Hammer Strength and delete Unlabelled?"*
    ///
    /// This breaks the app's no-confirmation posture deliberately: it is the only action
    /// irreversible *in principle* — once the entries are re-pointed nothing records that
    /// they were ever separate — and the direction is the thing people get wrong, so both
    /// machines are named in the order the entries travel.
    var question: String {
        guard movingCount > 0 else {
            return "Delete \(loser.name) and keep \(sibling.name)?"
        }
        return "Move \(entries(movingCount)) to \(sibling.name) and delete \(loser.name)?"
    }

    /// The line under the question: where the numbers end up, and that nothing brings
    /// them back.
    var detail: String {
        guard movingCount > 0 else {
            return "\(loser.name) holds no entries. \(sibling.name) keeps its \(entries(resultingCount)). This cannot be undone."
        }
        return "\(sibling.name) holds \(entries(resultingCount)) afterwards. This cannot be undone."
    }

    private func entries(_ count: Int) -> String {
        count == 1 ? "1 entry" : "\(count) entries"
    }
}
