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
        // Each gym's recency is read once, before the sort: the comparator runs
        // O(n log n) times and every call would walk the machines' entries again.
        gyms
            .map { (gym: $0, lastLogged: lastLogged(at: $0)) }
            .sorted { left, right in
                if (left.gym === current) != (right.gym === current) {
                    return left.gym === current
                }
                switch (left.lastLogged, right.lastLogged) {
                case let (leftDate?, rightDate?) where leftDate != rightDate:
                    return leftDate > rightDate
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                default:
                    return left.gym.name.localizedStandardCompare(right.gym.name) == .orderedAscending
                }
            }
            .map(\.gym)
    }

    /// When you last lifted at a gym, across every machine it holds. `nil` for a gym
    /// you have never logged at — a freshly created one, or one whose machines are all
    /// empty.
    ///
    /// Recency is the last *lift*, the same rule the library's tile order uses: a zeroed
    /// row is not something you did (SPEC §3), so it floats nothing.
    static func lastLogged(at gym: Gym) -> Date? {
        (gym.machines ?? [])
            .flatMap { $0.entries ?? [] }
            .filter(\.isALift)
            .map(\.date)
            .max()
    }
}
