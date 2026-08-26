import Foundation

/// The twelve rep-maxes for one exercise, derived from its entries and never stored
/// (SPEC §4, ADR-0002).
///
/// A plain struct over `[Entry]` — no `ModelContainer`, no fetch, no SwiftData beyond
/// the `Entry` type itself. **Scoping is the caller's job**: a free-weight exercise
/// passes every entry it has, a gym-bound one passes a single machine's entries.
/// Hints never enter the derivation.
struct RepMaxCurve {

    /// The rep counts the curve is drawn on. Fixed, so shapes compare between exercises.
    static let repRange = 1...12

    /// `best[n] = max(weight) over all entries with reps >= n`, for `n` in 1...12.
    ///
    /// Absent where no entry reaches that rep count — an absent cell is "not yet
    /// proven", never zero. Backfilled cells are indistinguishable from directly
    /// proven ones by design: the flat run reads as a floor on its own.
    let best: [Int: Double]

    /// How many entries stand behind each cell: the count of entries with `reps >= n`,
    /// for `n` in 1...12.
    ///
    /// The `M` in the readout's `best for N reps · M records ›` — the screen's wording,
    /// SPEC §5.1's — and exactly the rows the history sheet lists (§5.6), so it is
    /// derived here off the same pass rather than counted again against a second rule
    /// that could drift. Keyed wherever `best` is keyed, and absent everywhere else.
    let entriesBehind: [Int: Int]

    /// The Epley projection drawn behind the curve, for `n` in 1...12.
    ///
    /// **Guidance only** — never a rep-max, never stored, never presented as a weight
    /// you have lifted. Empty only when there is nothing to derive from, in which case
    /// no chart is drawn at all.
    let ghost: [Int: Double]

    /// One O(n) pass over the entries, then one sweep down the axis. Twelve
    /// `reps >= n` scans would be the obvious shape and are the wrong one.
    init(entries: [Entry]) {
        // Entries above 12 reps floor the whole axis but get no point of their own,
        // so they land on cell 12 alongside genuine twelves.
        var heaviest: [Int: Double] = [:]
        var reached: [Int: Int] = [:]
        var highestEstimated1RM: Double = 0

        for entry in entries {
            // Every `Entry` attribute is defaulted to keep the schema CloudKit-shaped
            // (ADR-0001), so a zeroed row is representable even though SPEC §3's
            // write-time guards reject one. It is not a lift, and it does not derive.
            guard entry.reps >= 1, entry.weight > 0 else { continue }

            let cell = min(entry.reps, Self.repRange.upperBound)
            heaviest[cell] = max(heaviest[cell] ?? 0, entry.weight)
            reached[cell, default: 0] += 1

            let estimate = entry.weight * Self.epleyFactor(reps: entry.reps)
            highestEstimated1RM = max(highestEstimated1RM, estimate)
        }

        // Sweeping downward turns each cell's own maximum into the monotonic backfill:
        // whatever floors 5 reps floors 4 and everything below it too.
        var best: [Int: Double] = [:]
        var entriesBehind: [Int: Int] = [:]
        var floor: Double?
        var counted = 0
        for n in Self.repRange.reversed() {
            if let own = heaviest[n] {
                floor = floor.map { max($0, own) } ?? own
            }
            counted += reached[n] ?? 0
            if let floor {
                best[n] = floor
                entriesBehind[n] = counted
            }
        }
        self.best = best
        self.entriesBehind = entriesBehind

        // A single estimated 1RM — the highest any one entry produces — projected back
        // across the axis. Drawn unconditionally whenever the curve is drawn at all.
        guard highestEstimated1RM > 0 else {
            self.ghost = [:]
            return
        }
        self.ghost = Dictionary(
            uniqueKeysWithValues: Self.repRange.map { n in
                (n, highestEstimated1RM / Self.epleyFactor(reps: n))
            }
        )
    }

    /// The Epley multiplier: an estimated 1RM is `w × (1 + reps/30)`, and projecting
    /// one back onto the axis divides by the same factor.
    private static func epleyFactor(reps: Int) -> Double {
        1 + Double(reps) / 30
    }
}
