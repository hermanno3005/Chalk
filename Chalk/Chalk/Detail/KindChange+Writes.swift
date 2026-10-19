import Foundation
import SwiftData

/// The writes behind `Change kind`, shared by both halves' detail models (SPEC §8,
/// §13.11): **the mechanism is one, and only the words differ.** Goals are the caller's —
/// each half moves its own before calling in, so they land in the same save.
extension KindChange {

    /// **Transferable / free-weight → gym-bound**: a new machine at `gym`, and **every
    /// existing entry gets it**, wholesale — no orphan and no "unknown machine" bucket to
    /// tidy later (SPEC §3, invariant 4). Unsaved: the caller saves once, with whatever
    /// else rides along.
    ///
    /// `name` is the same optional one-field answer `New machine here` asks for, `nil`
    /// where you skipped it. The machine is made through the one door every new machine
    /// goes through (`Machine.made`), so an erg's same-gym near name would pick its
    /// machine there — which, with a transferable erg holding no machines, it never finds.
    func placeEntries(at gym: Gym, named name: String?, in context: ModelContext) -> Machine {
        let machine = Machine.made(for: exercise, at: gym, named: name, in: context)
        for entry in exercise.entries ?? [] {
            entry.machine = machine
        }
        exercise.kind = ExerciseKind.gymBound.rawValue
        return machine
    }

    /// **Gym-bound → free-weight / transferable**: pool everything. Entries keep their
    /// exercise and **nullify their machine link**; the now-meaningless `Machine` rows are
    /// deleted. Returns whether the flip happened.
    ///
    /// > **The same cascade hazard as the merge** (ADR-0002). Deletion runs from `Machine`
    /// > to its entries (SPEC §3), so the order below is load-bearing: every entry is
    /// > detached and **flushed to the store before any machine row goes**. Its save error
    /// > is not swallowed — everywhere else the change simply waits in the context for the
    /// > next save, but here the next statement destroys history.
    ///
    /// On a failed flush nothing reached the store, so the entries are still their
    /// machines' and deleting one would cascade over them. The flip is abandoned whole
    /// rather than left half-applied, where a later save would commit the kind without the
    /// detaching. `rollback()` discards everything unsaved on the context — this flip, and
    /// any goal the caller moved for it: every other write in the app saves as it goes.
    ///
    /// **A machine still holding an entry after that flush is left standing.** In a store
    /// this app wrote there is none — every entry it holds is the exercise's, and they were
    /// all just detached — so the guard only fires over a row that arrived some other way,
    /// holding an entry with no exercise of its own (SPEC §3, invariant 2). **A stranded
    /// row is a nuisance; a lost entry is not.**
    func pool(in context: ModelContext) -> Bool {
        let machines = self.machines
        // The exercise's own entries, and no others: an entry with no exercise is treated
        // as non-existent — never repaired, never surfaced, never counted (SPEC §3,
        // invariant 2) — so this does not reach through the machines to go looking for one.
        for entry in exercise.entries ?? [] {
            entry.machine = nil
        }
        exercise.kind = ExerciseKind.freeWeight.rawValue
        do {
            try context.save()
        } catch {
            context.rollback()
            return false
        }

        for machine in machines where (machine.entries ?? []).isEmpty {
            context.delete(machine)
        }
        // As everywhere else: v1 has no error state past §3's container failure.
        try? context.save()
        return true
    }
}
