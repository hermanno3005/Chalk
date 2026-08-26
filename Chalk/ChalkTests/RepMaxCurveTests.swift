import Foundation
import Testing

@testable import Chalk

/// The derivation from SPEC §4, governed by ADR-0002. Monotonic backfill, the
/// `reps > 12` flooring rule and the Epley ghost are the three things an implementer
/// gets subtly wrong, so they get tests rather than a demo.
///
/// Not one of these builds a `ModelContainer`: `RepMaxCurve` is a plain struct over
/// `[Entry]`, and that is the point of it.
@Suite("Rep-max curve")
struct RepMaxCurveTests {

    // MARK: - Monotonic backfill

    @Test("A single entry floors every rep count at or below its own")
    func singleEntryFloorsDownward() {
        let curve = RepMaxCurve(entries: [Entry(reps: 5, weight: 55)])

        #expect(curve.best[1] == 55)
        #expect(curve.best[2] == 55)
        #expect(curve.best[3] == 55)
        #expect(curve.best[4] == 55)
        #expect(curve.best[5] == 55)
    }

    @Test("A rep count no entry reaches is absent from best")
    func unreachedRepCountsAreAbsent() {
        let curve = RepMaxCurve(entries: [Entry(reps: 5, weight: 55)])

        #expect(curve.best[6] == nil)
        #expect(curve.best[12] == nil)
        #expect(curve.best.keys.sorted() == [1, 2, 3, 4, 5])
    }

    @Test("An entry above 12 reps floors all twelve without appearing as a point")
    func entriesAboveTwelveRepsFloorTheWholeAxis() {
        let curve = RepMaxCurve(entries: [Entry(reps: 25, weight: 30)])

        #expect(curve.best.keys.sorted() == Array(1...12))
        #expect(curve.best.values.allSatisfy { $0 == 30 } )
        #expect(curve.best[25] == nil)
        #expect(curve.best[13] == nil)
    }

    @Test("A lower-weight higher-rep entry does not displace a heavier one")
    func heavierEntryIsNotDisplaced() {
        let curve = RepMaxCurve(entries: [
            Entry(reps: 3, weight: 100),
            Entry(reps: 10, weight: 70),
        ])

        #expect(curve.best[1] == 100)
        #expect(curve.best[3] == 100)
        #expect(curve.best[4] == 70)
        #expect(curve.best[10] == 70)
        #expect(curve.best[11] == nil)
    }

    @Test("The heaviest entry at a rep count wins, whatever the order")
    func heaviestAtEachRepCountWins() {
        let curve = RepMaxCurve(entries: [
            Entry(reps: 5, weight: 60),
            Entry(reps: 5, weight: 80),
            Entry(reps: 5, weight: 70),
        ])

        #expect(curve.best[5] == 80)
        #expect(curve.best[1] == 80)
    }

    @Test("The curve is non-increasing across the axis")
    func curveIsNonIncreasing() {
        let curve = RepMaxCurve(entries: [
            Entry(reps: 1, weight: 120),
            Entry(reps: 6, weight: 90),
            Entry(reps: 20, weight: 50),
        ])

        let values = (1...12).compactMap { curve.best[$0] }
        #expect(values.count == 12)
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 >= $1 })
        #expect(curve.best[1] == 120)
        #expect(curve.best[2] == 90)
        #expect(curve.best[7] == 50)
    }

    @Test("No entries means no curve and no ghost")
    func noEntries() {
        let curve = RepMaxCurve(entries: [])

        #expect(curve.best.isEmpty)
        #expect(curve.ghost.isEmpty)
    }

    @Test("A zeroed row is not a lift and derives nothing")
    func zeroedRowsDoNotDerive() {
        // Every Entry attribute is defaulted to keep the schema CloudKit-shaped
        // (ADR-0001), so a zeroed row is representable even though SPEC §3's
        // write-time guards reject one.
        let curve = RepMaxCurve(entries: [
            Entry(),
            Entry(reps: 0, weight: 100),
            Entry(reps: 5, weight: 0),
            Entry(reps: 5, weight: 55),
        ])

        #expect(curve.best.keys.sorted() == [1, 2, 3, 4, 5])
        #expect(curve.best[5] == 55)
        #expect(isClose(curve.ghost[5], 55.0))
    }

    // MARK: - The entries behind a cell

    @Test("The entries behind a cell are every entry at or above its rep count")
    func entriesBehindACellCountFromItsRepCountUp() {
        let curve = RepMaxCurve(entries: [
            Entry(reps: 3, weight: 100),
            Entry(reps: 5, weight: 90),
            Entry(reps: 5, weight: 85),
        ])

        #expect(curve.entriesBehind[1] == 3)
        #expect(curve.entriesBehind[3] == 3)
        #expect(curve.entriesBehind[4] == 2)
        #expect(curve.entriesBehind[5] == 2)
    }

    @Test("A rep count no entry reaches has no count at all")
    func entriesBehindIsKeyedWhereBestIs() {
        let curve = RepMaxCurve(entries: [Entry(reps: 5, weight: 55)])

        #expect(curve.entriesBehind[5] == 1)
        #expect(curve.entriesBehind[6] == nil)
        #expect(curve.entriesBehind.keys.sorted() == curve.best.keys.sorted())
    }

    @Test("An entry above 12 reps counts towards every cell it floors")
    func entriesBehindCountEntriesAboveTwelveReps() {
        let curve = RepMaxCurve(entries: [Entry(reps: 25, weight: 30)])

        #expect(curve.entriesBehind[1] == 1)
        #expect(curve.entriesBehind[12] == 1)
        #expect(curve.entriesBehind.keys.sorted() == Array(1...12))
    }

    @Test("A zeroed row is counted no more than it is derived from")
    func entriesBehindIgnoreZeroedRows() {
        let curve = RepMaxCurve(entries: [Entry(), Entry(reps: 5, weight: 55)])

        #expect(curve.entriesBehind[5] == 1)
    }

    // MARK: - The Epley ghost

    @Test("The ghost projects one estimated 1RM back across all twelve rep counts")
    func ghostFromASingleEntry() {
        let curve = RepMaxCurve(entries: [Entry(reps: 5, weight: 100)])

        // Epley: 100 × (1 + 5/30) = 116.6666…
        // ghost[n] = e1RM / (1 + n/30)
        #expect(curve.ghost.keys.sorted() == Array(1...12))
        #expect(isClose(curve.ghost[1], 112.90322580645162))
        #expect(isClose(curve.ghost[5], 100.0))
        #expect(isClose(curve.ghost[12], 83.33333333333333))
    }

    @Test("The ghost takes the single highest estimated 1RM, not the heaviest entry")
    func ghostTakesTheHighestEstimate() {
        let curve = RepMaxCurve(entries: [
            Entry(reps: 1, weight: 110),   // e1RM 113.6666…
            Entry(reps: 10, weight: 90),   // e1RM 120.0 — wins
            Entry(reps: 5, weight: 100),   // e1RM 116.6666…
        ])

        // 120 / (1 + 1/30) = 116.129032…, 120 / (1 + 12/30) = 85.714285…
        #expect(isClose(curve.ghost[1], 116.12903225806451))
        #expect(isClose(curve.ghost[12], 85.71428571428571))
    }

    @Test("An entry above 12 reps still feeds the ghost")
    func ghostFromAnEntryAboveTwelveReps() {
        let curve = RepMaxCurve(entries: [Entry(reps: 25, weight: 30)])

        // Epley: 30 × (1 + 25/30) = 55.0
        #expect(curve.ghost.keys.sorted() == Array(1...12))
        #expect(isClose(curve.ghost[1], 53.225806451612904))
        #expect(isClose(curve.ghost[12], 39.285714285714285))
    }

    @Test("The ghost sits above the curve it is drawn behind")
    func ghostIsHeadroom() {
        let curve = RepMaxCurve(entries: [Entry(reps: 5, weight: 100)])

        for n in 1...5 {
            #expect(curve.ghost[n]! >= curve.best[n]! - 1e-9)
        }
    }

    // MARK: -

    private func isClose(_ value: Double?, _ expected: Double) -> Bool {
        guard let value else { return false }
        return abs(value - expected) < 1e-9
    }
}
