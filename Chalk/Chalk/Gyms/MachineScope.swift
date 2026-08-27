import Foundation

/// Which machine a gym-bound screen opens on, and what a curve is derived from
/// (SPEC §5.3, §4).
///
/// **Scoping is the caller's job** — `RepMaxCurve` takes an array and derives it, so a
/// gym-bound exercise differs from a free-weight one by the array it is handed and by
/// nothing else.
enum MachineScope {

    /// The machine a gym-bound detail screen opens scoped to (SPEC §5.3):
    ///
    /// 1. the machine at the **current gym** if there is exactly one;
    /// 2. if the current gym holds several, the one most recently logged on;
    /// 3. if the current gym holds none — or no gym is selected — the machine most
    ///    recently logged on **overall**;
    /// 4. `nil` where the exercise has no machines at all, which is the empty state
    ///    until the first log creates one (§6.4).
    ///
    /// Where a rung has nothing logged to rank by, the name settles it: a gym-bound
    /// exercise that *has* machines must always resolve one (SPEC §3, invariant 4), so
    /// no rung is allowed to fall through for want of an entry.
    static func opening(machines: [Machine], currentGym: Gym?) -> Machine? {
        guard !machines.isEmpty else { return nil }

        if let currentGym {
            let here = machines.filter { $0.gym?.id == currentGym.id }
            if here.count == 1 { return here.first }
            if here.count > 1 { return mostRecentlyLogged(here) }
        }
        return mostRecentlyLogged(machines)
    }

    /// The entries one screen derives from: **one machine's** for a gym-bound exercise,
    /// **every one the exercise has** for a free-weight one.
    ///
    /// A gym-bound exercise with no machine resolved derives from nothing rather than
    /// from the exercise's entries — pooling separate machines' numbers is exactly the
    /// pollution the model forbids (SPEC §3, invariant 4).
    static func entries(of exercise: Exercise, on machine: Machine?) -> [Entry] {
        guard exercise.isGymBound else { return exercise.entries ?? [] }
        return machine?.entries ?? []
    }

    /// Most recently logged first, never-logged after them, ties by name — the same rule
    /// the library orders tiles by, over machines instead of exercises.
    static func byRecency(_ machines: [Machine]) -> [Machine] {
        Recency.order(machines, lastUsed: \.lastLogged, name: \.name)
    }

    private static func mostRecentlyLogged(_ machines: [Machine]) -> Machine? {
        byRecency(machines).first
    }
}
