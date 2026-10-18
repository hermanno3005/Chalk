import Foundation
import Testing

@testable import Chalk

/// The endurance goal's derivation (ADR-0007): a point on the zone line, reached by its
/// ten-visit mean, with the gap, the origin and the ring's fill read off the scope's
/// entries each time and none of them stored.
///
/// The rules an implementer gets subtly wrong: **only the exact point counts** — no
/// backfill across zones or durations, as strength's goal backfills across reps — and a
/// reached goal **un-reaches with no edit** when a slower visit pushes the window. Every
/// comparison is in the unit's whole steps.
///
/// Not one of these builds a `ModelContainer`: `EnduranceGoal` is a plain struct over
/// `[Entry]`, as `ZoneLine` is.
@Suite("Endurance goal")
struct EnduranceGoalTests {

    /// Z2 from 120, Z3 from 140, Z4 from 158, Z5 from 170.
    private let zones = HeartRateZones(lowerBounds: [120, 140, 158, 170])!

    /// Day 10, at noon UTC.
    private var setAt: Date { date(day: 10) }

    // MARK: - No goal

    @Test("A partly filled set of fields is no goal", arguments: [
        (Int?.none, Int?.some(360), Double?.some(15.5), Date?.some(Date(timeIntervalSince1970: 0))),
        (Int?.some(4), Int?.none, Double?.some(15.5), Date?.some(Date(timeIntervalSince1970: 0))),
        (Int?.some(4), Int?.some(360), Double?.none, Date?.some(Date(timeIntervalSince1970: 0))),
        (Int?.some(4), Int?.some(360), Double?.some(15.5), Date?.none),
    ])
    func aPartialSetIsNoGoal(zone: Int?, duration: Int?, intensity: Double?, setAt: Date?) {
        #expect(EnduranceGoal(
            zone: zone, duration: duration, intensity: intensity, incline: 1, setAt: setAt,
            entries: [], zones: zones, unit: .speed
        ) == nil)
    }

    @Test("A speed goal with no incline is no goal")
    func aSpeedGoalNeedsAnIncline() {
        #expect(goal(intensity: 15.5, incline: nil, []) == nil)
    }

    @Test("A goal on any other unit needs no incline, and ignores one")
    func otherUnitsNeedNoIncline() throws {
        let watts = try #require(goal(unit: .watts, intensity: 260, incline: nil, []))
        #expect(watts.incline == nil)
        let stray = try #require(goal(unit: .watts, intensity: 260, incline: 2, []))
        #expect(stray.incline == nil)
    }

    @Test("Every field set makes a goal, named as every surface names it")
    func aFullSetIsAGoal() throws {
        let speed = try #require(goal(intensity: 15.5, incline: 1, []))
        #expect(speed.text.decimalPoint == "15.5 km/h · 6:00 in Z4 · 1 %")

        let watts = try #require(goal(unit: .watts, zone: 3, duration: 600, intensity: 260, incline: nil, []))
        #expect(watts.text == "260 W · 10:00 in Z3")
    }

    @Test("A level goal is named L12, the goal line's short form, not Level 12")
    func aLevelGoalIsNamedShort() throws {
        let level = try #require(goal(unit: .level, zone: 3, duration: 600, intensity: 12, incline: nil, []))
        #expect(level.text == "L12 · 10:00 in Z3")
    }

    // MARK: - Reached

    @Test("A goal is reached when the point's mean meets it exactly")
    func reachedAtExactlyTheGoal() throws {
        let goal = try #require(goal(intensity: 15.5, [interval(at: 15.5, day: 11)]))
        #expect(goal.current == 15.5)
        #expect(goal.isReached)
    }

    @Test("A goal is reached on the point's mean, not on its best entry")
    func reachedOnTheMean() throws {
        // One fast day and one slow: the mean, 15.3, is what the readout shows.
        let entries = [interval(at: 15.6, day: 11), interval(at: 15.0, day: 12)]
        let goal = try #require(goal(intensity: 15.5, entries))
        #expect(goal.current == 15.3)
        #expect(!goal.isReached)
    }

    @Test("A goal is reached in whole steps, whatever the binary mean")
    func reachedInSteps() throws {
        // Nine 15.1s average a hair off 15.1 in binary; in steps they are 151.
        let entries = (11...19).map { interval(at: 15.1, day: $0) }
        let goal = try #require(goal(intensity: 15.1, entries))
        #expect(goal.isReached)
        #expect(goal.gap == 0)
    }

    @Test("A split goal is reached at or under it — lower is harder")
    func aSplitIsReachedBelow() throws {
        let at = try #require(goal(unit: .split, intensity: 105, incline: nil, [interval(at: 105, day: 11)]))
        #expect(at.isReached)
        let under = try #require(goal(unit: .split, intensity: 105, incline: nil, [interval(at: 104.5, day: 11)]))
        #expect(under.isReached)
        let over = try #require(goal(unit: .split, intensity: 105, incline: nil, [interval(at: 105.2, day: 11)]))
        #expect(!over.isReached)
    }

    @Test("A reached goal un-reaches when a slower visit pushes a faster one out of the window")
    func aSlowerVisitUnReaches() throws {
        // Ten visits at 15.5 reach it; an eleventh at 14.5 pushes the first out.
        let ten = (11...20).map { interval(at: 15.5, day: $0) }
        #expect(try #require(goal(intensity: 15.5, ten)).isReached)

        let eleven = ten + [interval(at: 14.5, day: 21)]
        let goal = try #require(goal(intensity: 15.5, eleven))
        #expect(goal.current == 15.4)
        #expect(!goal.isReached)
    }

    // MARK: - The gap

    @Test("The gap is in the unit's own step, for every unit", arguments: [
        (ErgUnit.speed, 15.5, 15.1, 4, "0.4 km/h to go"),
        (ErgUnit.watts, 260, 248, 12, "12 W to go"),
        (ErgUnit.split, 105, 107, 20, "2 s to go"),
        (ErgUnit.split, 105, 106.5, 15, "1.5 s to go"),
        (ErgUnit.level, 12, 10, 2, "2 levels to go"),
        (ErgUnit.level, 12, 11, 1, "1 level to go"),
    ])
    func theGapInSteps(unit: ErgUnit, goal intensity: Double, held: Double, steps: Int, status: String) throws {
        let goal = try #require(goal(unit: unit, intensity: intensity, incline: 0, [interval(at: held, day: 11)]))
        #expect(goal.gap == steps)
        #expect(goal.status.decimalPoint == status)
    }

    @Test("A reached goal has no gap and reads reached")
    func aReachedGoalReadsReached() throws {
        let goal = try #require(goal(intensity: 15.5, [interval(at: 15.8, day: 11)]))
        #expect(goal.gap == 0)
        #expect(goal.status == "reached")
    }

    // MARK: - Origin and progress

    @Test("The origin is the point over the entries strictly before the goal was set")
    func theOriginIsThePointBeforeSetting() throws {
        let entries = [
            interval(at: 14.0, day: 8),
            interval(at: 14.4, day: 9),
            // Set at noon on day 10; this one, at the same moment, is after.
            interval(at: 15.0, day: 10),
        ]
        let goal = try #require(goal(intensity: 15.5, entries))
        #expect(goal.origin == 14.2)
        #expect(goal.current == 14.5)
    }

    @Test("With nothing before, the origin is the point as of the first visit after")
    func theOriginIsTheFirstVisitAfter() throws {
        let entries = [
            // Held in another zone before: no point here, so no origin from then.
            interval(at: 15.0, bpm: 150, day: 9),
            interval(at: 14.0, day: 11),
            interval(at: 14.4, day: 11, minute: 30),
            interval(at: 15.4, day: 12),
        ]
        let goal = try #require(goal(intensity: 15.5, entries))
        #expect(goal.origin == 14.2)
        #expect(goal.current == 14.6)
        // 0.4 of the 1.3 from 14.2 to 15.5.
        #expect(abs(goal.progress - 4.0 / 13.0) < 1e-9)
    }

    @Test("A goal with no point has no origin and an empty ring")
    func noPointNoOrigin() throws {
        let goal = try #require(goal(intensity: 15.5, []))
        #expect(goal.origin == nil)
        #expect(goal.progress == 0)
    }

    @Test("Progress falls back below the origin to an empty ring, never a negative one")
    func progressClampsAtZero() throws {
        let entries = [interval(at: 15.0, day: 9), interval(at: 14.0, day: 11)]
        let goal = try #require(goal(intensity: 15.5, entries))
        #expect(goal.origin == 15.0)
        #expect(goal.current == 14.5)
        #expect(goal.progress == 0)
    }

    @Test("A reached goal's ring is full")
    func progressIsOneWhenReached() throws {
        let entries = [interval(at: 15.0, day: 9), interval(at: 16.5, day: 11)]
        let goal = try #require(goal(intensity: 15.5, entries))
        #expect(goal.isReached)
        #expect(goal.progress == 1)
    }

    @Test("A split's progress runs downward, as the split does")
    func splitProgressIsReversed() throws {
        let entries = [interval(at: 110, day: 9), interval(at: 106, day: 11)]
        let goal = try #require(goal(unit: .split, intensity: 105, incline: nil, entries))
        #expect(goal.origin == 110)
        // 1:47.9 by the power-weighted mean of 1:50 and 1:46: 2.1 s of the 5 s to go.
        #expect(goal.current == 107.9)
        #expect(abs(goal.progress - 0.42) < 1e-9)
    }

    // MARK: - No backfill

    @Test("A lower zone at the goal's intensity never counts")
    func noBackfillAcrossZones() throws {
        // 15.5 km/h held for 6:00 in Z3 (150 bpm) says nothing of Z4.
        let goal = try #require(goal(intensity: 15.5, [interval(at: 15.5, bpm: 150, day: 11)]))
        #expect(goal.current == nil)
        #expect(!goal.isReached)
    }

    @Test("A longer duration at the goal's intensity never counts")
    func noBackfillAcrossDurations() throws {
        let goal = try #require(goal(intensity: 15.5, [interval(420, at: 16.0, day: 11)]))
        #expect(goal.current == nil)
        #expect(!goal.isReached)
    }

    @Test("Another incline at the goal's intensity never counts on a speed erg")
    func noBackfillAcrossInclines() throws {
        let goal = try #require(goal(intensity: 15.5, incline: 1, [interval(at: 16.0, incline: 0, day: 11)]))
        #expect(goal.current == nil)
    }

    // MARK: - Not held yet

    @Test("A goal with no point has no gap and reads not held yet")
    func noPointIsNotHeldYet() throws {
        let goal = try #require(goal(intensity: 15.5, []))
        #expect(goal.current == nil)
        #expect(goal.gap == nil)
        #expect(goal.status == "not held yet")
    }

    @Test("A goal over 20:00 reads against its undrawn point once you do one")
    func aGoalOverTwentyMinutes() throws {
        let none = try #require(goal(duration: 1500, intensity: 12.5, []))
        #expect(none.status == "not held yet")

        let goal = try #require(goal(duration: 1500, intensity: 12.5, [interval(1500, at: 12.5, day: 11)]))
        #expect(goal.current == 12.5)
        #expect(goal.isReached)
    }

    @Test("Without zones no point can be read, and the goal reads not held yet")
    func noZonesNoPoint() throws {
        let goal = try #require(EnduranceGoal(
            zone: 4, duration: 360, intensity: 15.5, incline: 0, setAt: setAt,
            entries: [interval(at: 16.0, day: 11)], zones: nil, unit: .speed, calendar: calendar
        ))
        #expect(goal.current == nil)
    }

    // MARK: -

    private func goal(
        unit: ErgUnit = .speed,
        zone: Int = 4,
        duration: Int = 360,
        intensity: Double,
        incline: Double? = 0,
        _ entries: [Entry]
    ) -> EnduranceGoal? {
        EnduranceGoal(
            zone: zone,
            duration: duration,
            intensity: intensity,
            incline: incline,
            setAt: setAt,
            entries: entries,
            zones: zones,
            unit: unit,
            calendar: calendar
        )
    }

    /// A valid interval on `day` days after a fixed start, at noon UTC.
    private func interval(
        _ duration: Int = 360,
        at intensity: Double,
        bpm: Int = 164,
        incline: Double = 0,
        day: Int,
        minute: Int = 0
    ) -> Entry {
        Entry(
            duration: duration,
            intensity: intensity,
            incline: incline,
            averageHeartRate: bpm,
            peakHeartRate: bpm + 5,
            date: date(day: day, minute: minute)
        )
    }

    private func date(day: Int, minute: Int = 0) -> Date {
        Date(timeIntervalSince1970: 1_700_006_400 + 43_200)
            .addingTimeInterval(Double(day) * 86_400 + Double(minute) * 60)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}
