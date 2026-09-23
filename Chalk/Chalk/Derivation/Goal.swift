import Foundation

/// A weight at a rep count you have not lifted yet, judged against one scope's entries
/// (ADR-0004). Only the three fields are stored; **reached, the gap, the origin and the
/// ring's fill are derived here each time**, so correcting an entry downward quietly
/// un-reaches a goal and there is no stale state to repair (ADR-0002).
///
/// **The only way to build a goal**: a partly filled set of fields is no goal at all.
///
/// A plain struct over `[Entry]`, beside `RepMaxCurve` and read off the same rule.
/// **Scoping is the caller's job**, exactly as it is there: every entry for a free-weight
/// exercise, one machine's entries for a gym-bound one.
struct Goal: Equatable {
    let reps: Int
    /// Kilograms.
    let weight: Double
    /// When the goal was last set — the moment the ring counts from.
    ///
    /// Stored as a moment rather than as the best you had then, because `Entry.date` never
    /// changes (SPEC §3): the before/after split is fixed, and an edited or deleted entry
    /// simply moves the origin with it.
    let setAt: Date

    /// `best[reps]` over the scope, **off the drawn axis**: a goal above 12 reps is an
    /// ordinary goal. Nil where nothing reaches that rep count yet.
    let current: Double?

    /// `best[reps]` over the scope's entries dated **strictly before** `setAt`, or zero
    /// when there are none — where the ring counts from. Since `current` is taken over a
    /// superset of these entries, `current >= origin` holds by construction.
    let origin: Double

    init?(reps: Int?, weight: Double?, setAt: Date?, entries: [Entry]) {
        guard let reps, let weight, let setAt else { return nil }
        self.reps = reps
        self.weight = weight
        self.setAt = setAt
        current = RepMaxCurve.best(atLeast: reps, in: entries)
        origin = RepMaxCurve.best(atLeast: reps, in: entries.filter { $0.date < setAt }) ?? 0
    }

    /// `best[reps] >= weight` — a 5-rep 95 reaches a 1-rep goal of 95.
    var isReached: Bool { (current ?? 0) >= weight }

    /// What is left between your best and the goal: the whole weight with nothing logged
    /// at that rep count, and zero once reached.
    var gap: Double { max(0, weight - (current ?? 0)) }

    /// How much of the way from the origin to the goal you have come: the donut's fill,
    /// within 0…1, and 1 once reached.
    var progress: Double {
        guard !isReached else { return 1 }
        let span = weight - origin
        guard span > 0 else { return 1 }
        return min(1, max(0, ((current ?? 0) - origin) / span))
    }
}
