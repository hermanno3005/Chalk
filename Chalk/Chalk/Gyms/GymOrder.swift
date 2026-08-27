import Foundation

/// The order gyms are drawn in: **when you last logged an entry there, most recent
/// first, with the current gym pinned to the top** (SPEC §7.4).
///
/// **Derived from entries — no stored index, no maintenance.** `Gym` deliberately has no
/// `sortIndex` (SPEC §3): the two or three gyms you actually use float on their own and
/// the holiday gym sinks, without anything to keep up to date and without an auto-archive
/// rule.
enum GymOrder {

    /// Gyms in the picker's order. `current` is pinned to the top however long ago you
    /// last logged there — it is where you are standing, which outranks recency.
    ///
    /// Archiving is not consulted here: what leaves the picker is the caller's call
    /// (SPEC §7.4), and the machine menu keeps archived gyms in a section of its own.
    static func byRecency(_ gyms: [Gym], current: Gym? = nil) -> [Gym] {
        let ordered = Recency.order(gyms, lastUsed: \.lastLogged, name: \.name)
        // Pinned after the fact rather than as a first case in the comparator: where you
        // are standing is not a recency, and folding it in there reads as one.
        guard let current, let index = ordered.firstIndex(where: { $0 === current }) else {
            return ordered
        }
        var pinned = ordered
        pinned.remove(at: index)
        pinned.insert(current, at: 0)
        return pinned
    }
}
