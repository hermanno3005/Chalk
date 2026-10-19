import Foundation
import Testing

@testable import Chalk

/// Every derived comparison of an intensity goes through **whole steps of its unit**
/// (ADR-0008). 0.1 km/h is not exact in binary floating point the way 2.5 kg is, so a
/// mean of nine `15.1`s is not `15.1` as a `Double` — and a goal of 15.1 km/h compared
/// with `>=` would miss by a rounding error. Comparing `Double`s directly is the bug.
@Suite("Unit steps")
struct ErgUnitTests {

    private func mean(_ values: [Double]) -> Double {
        values.reduce(0, +) / Double(values.count)
    }

    @Test("A mean of 15.1s compares equal to 15.1 in steps, whichever way it drifts")
    func aDriftedMeanIsTheSameStep() {
        let above = mean(Array(repeating: 15.1, count: 9))
        let below = mean(Array(repeating: 15.1, count: 13))
        #expect(above != 15.1)
        #expect(below != 15.1)

        #expect(ErgUnit.speed.steps(above) == ErgUnit.speed.steps(15.1))
        #expect(ErgUnit.speed.steps(below) == ErgUnit.speed.steps(15.1))
    }

    @Test("Speed and split step in tenths, watts and level in wholes")
    func eachUnitsStep() {
        #expect(ErgUnit.speed.steps(15.1) == 151)
        #expect(ErgUnit.split.steps(105.3) == 1053)
        #expect(ErgUnit.watts.steps(220) == 220)
        #expect(ErgUnit.level.steps(12) == 12)
    }

    @Test("One step apart is never the same step")
    func adjacentStepsDiffer() {
        #expect(ErgUnit.speed.steps(15.0) < ErgUnit.speed.steps(15.1))
        #expect(ErgUnit.split.steps(105.2) < ErgUnit.split.steps(105.3))
        #expect(ErgUnit.watts.steps(219) < ErgUnit.watts.steps(220))
        #expect(ErgUnit.level.steps(11) < ErgUnit.level.steps(12))
    }

    @Test("Rounding lands on the nearest step of the unit", arguments: [
        (ErgUnit.speed, 15.14, 15.1),
        (ErgUnit.speed, 15.16, 15.2),
        (ErgUnit.split, 105.33, 105.3),
        (ErgUnit.watts, 220.4, 220),
        (ErgUnit.watts, 220.6, 221),
        (ErgUnit.level, 11.6, 12),
    ])
    func roundsToNearestStep(unit: ErgUnit, value: Double, expected: Double) {
        #expect(unit.rounded(value) == expected)
    }

    @Test("A drifted mean rounds back to exactly the value you typed")
    func roundingUndoesTheDrift() {
        #expect(ErgUnit.speed.rounded(mean(Array(repeating: 15.1, count: 9))) == 15.1)
        #expect(ErgUnit.speed.rounded(mean(Array(repeating: 15.1, count: 13))) == 15.1)
    }
}
