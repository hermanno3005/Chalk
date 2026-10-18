import Foundation
import Testing

@testable import Chalk

/// The endurance twin of `isALift` (ADR-0008): **duration, intensity and average heart
/// rate all set**. Peak and incline are not part of it — an incline of 0 % is a real
/// value, and peak is never read by the derivation — and a lift is never an interval,
/// since every interval field on it is at its default.
///
/// Not one of these builds a `ModelContainer`: the check is a property of one row.
@Suite("Valid interval")
struct ValidIntervalTests {

    @Test("Duration, intensity and average heart rate make a valid interval")
    func theThreeFieldsMakeAnInterval() {
        let entry = Entry(duration: 360, intensity: 15.0, averageHeartRate: 164)

        #expect(entry.isAnInterval)
        #expect(!entry.isALift)
    }

    @Test("Peak heart rate and incline are not needed for a valid interval")
    func peakAndInclineAreNotPartOfTheCheck() {
        let entry = Entry(duration: 360, intensity: 15.0, incline: 0, averageHeartRate: 164, peakHeartRate: 0)

        #expect(entry.isAnInterval)
    }

    @Test("An interval missing any one of the three is not valid", arguments: [
        (0, 15.0, 164),
        (360, 0.0, 164),
        (360, 15.0, 0),
    ])
    func anyMissingFieldIsNoInterval(duration: Int, intensity: Double, averageHeartRate: Int) {
        let entry = Entry(duration: duration, intensity: intensity, averageHeartRate: averageHeartRate)

        #expect(!entry.isAnInterval)
    }

    @Test("A lift is never a valid interval")
    func aLiftIsNoInterval() {
        let entry = Entry(reps: 5, weight: 100)

        #expect(entry.isALift)
        #expect(!entry.isAnInterval)
    }

    @Test("A zeroed row is neither a lift nor a valid interval")
    func aZeroedRowIsNeither() {
        let entry = Entry()

        #expect(!entry.isALift)
        #expect(!entry.isAnInterval)
    }
}
