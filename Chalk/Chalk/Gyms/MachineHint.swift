import Foundation

/// Your numbers for the same exercise on a **different** machine, shown where the
/// machine in front of you has no history of its own (SPEC §5.4, §6.5).
///
/// **Never part of any derivation.** It is a lookup that produces one sentence, and the
/// sentence is the whole of it: no cell of a curve is filled from here, nothing is drawn
/// on a chart from here, and no seed is taken from here. The one place in the app that
/// reads a machine's entries while a different machine is in scope.
///
/// **One lookup, two surfaces.** The detail screen's empty state and the log sheet's
/// fifth verdict state quote the same sentence about the same sibling, so they cannot
/// disagree about what your numbers elsewhere are.
struct MachineHint: Equatable {

    /// The rep count every hint quotes. **Fixed**, so the sentence agrees with the log
    /// sheet's cold start (SPEC §6.3) — and where the sibling cannot back that rep count
    /// up, the hint stays silent rather than sliding down to one it can (§5.4).
    static let reps = 5

    /// The sibling's `best[5]`.
    let weight: Double

    /// What the sibling is called — its name alone, not its `label · gym` caption. The
    /// sentence is already long, and the hint says *whose numbers these are*, not where
    /// to walk.
    let machineName: String

    /// `55 kg × 5 on Hammer Strength` — the clause both surfaces draw, and the whole of
    /// what the lookup found.
    var text: String {
        "\(weight.kilogramsText) kg × \(Self.reps) on \(machineName)"
    }

    /// The line under the empty state's text, on the detail screen (SPEC §5.4).
    var emptyStateLine: String { "No entries here — \(text)" }

    /// The verdict line's fifth state, in the log sheet (SPEC §6.5).
    ///
    /// The two lead-ins are the spec's own words, kept here beside the clause they wrap
    /// so the app's copy for one idea lives in one place rather than either surface's
    /// view code.
    var verdictLine: String { "No history here — \(text)" }

    /// The hint for one gym-bound screen, or `nil` where there is nothing honest to say.
    ///
    /// Silent in every one of these cases, and the silence is the point — a hint that
    /// guesses is worse than no hint:
    ///
    /// - a **free-weight** exercise, whose load transfers between gyms and so has no
    ///   sibling to quote;
    /// - a machine that **has history of its own**, which is a real verdict's job;
    /// - **no sibling ever logged on**;
    /// - a sibling with **no `best[5]`** — do not fall back to `best[3]`, and do not step
    ///   over it to a quieter machine: the screen shows one hint, never a list.
    ///
    /// `machine` is the scope the screen is in, and `nil` is a real one: the first log at
    /// a gym holding no machine for this exercise (SPEC §6.4), where every machine you
    /// own is a sibling and the numbers you have are all somewhere else.
    ///
    /// **An archived gym's machine is quotable like any other.** Archived is a matter of
    /// display, and no rep-max is affected by it — the numbers you lifted there are still
    /// yours, and nothing in the spec ranks siblings beyond the date.
    static func lookUp(_ exercise: Exercise, scopedTo machine: Machine?) -> MachineHint? {
        lookUp(
            exercise,
            scopedTo: machine,
            historyHere: MachineScope.entries(of: exercise, on: machine)
        )
    }

    /// The same lookup over a scope the caller already holds — the log sheet's, which is
    /// this machine's entries **minus the one being corrected** (SPEC §6.6). One rule for
    /// "nothing has been lifted here", read off the array the screen is deriving against
    /// rather than off a second fetch that could disagree with it.
    static func lookUp(
        _ exercise: Exercise,
        scopedTo machine: Machine?,
        historyHere entries: [Entry]
    ) -> MachineHint? {
        guard exercise.isGymBound else { return nil }
        // A machine with a lift on it speaks for itself.
        guard !entries.contains(where: \.isALift) else { return nil }

        let siblings = (exercise.machines ?? []).filter { $0 !== machine }
        // Most recently logged first — the app's one recency rule, over machines
        // (SPEC §5.3) — so the sibling is `max(by:)` over `Entry.date` and ties settle
        // by name rather than by whatever order the store handed them back in. A sibling
        // nobody has logged on has no `best[5]` either, so it falls out below.
        guard let sibling = MachineScope.byRecency(siblings).first,
              let best = RepMaxCurve.best(atLeast: reps, in: sibling.entries ?? [])
        else { return nil }

        return MachineHint(weight: best, machineName: sibling.name)
    }
}
