import Foundation
import Testing

@testable import Chalk

/// The zone line from SPEC §13.4, governed by ADR-0006. Three rules are the ones an
/// implementer gets subtly wrong, so they get tests rather than a demo:
///
/// - **Membership** is the average heart rate's alone, with a heart rate exactly on a
///   boundary in the upper zone. Peak is never read.
/// - **Durations group exactly as typed**: a `6:02` is its own point, never `6:00`'s.
/// - **The window is the last ten visits** — calendar days, not entries and not a span of
///   time — so five reps in a day are one visit and nothing moves until a new visit does.
///
/// Not one of these builds a `ModelContainer`: `ZoneLine` is a plain struct over
/// `[Entry]`, as `RepMaxCurve` is.
@Suite("Zone line")
struct ZoneLineTests {

    /// Z2 from 120, Z3 from 140, Z4 from 158, Z5 from 170.
    private let zones = Bounds(z2: 120, z3: 140, z4: 158, z5: 170)

    // MARK: - Membership

    @Test("A heart rate exactly on a boundary joins the upper zone")
    func aBoundaryHeartRateGoesUp() {
        let entries = [interval(360, at: 15.0, bpm: 158)]

        #expect(line(entries, zone: 4).points.map(\.duration) == [360])
        #expect(line(entries, zone: 3).points.isEmpty)
    }

    @Test("A heart rate one below a boundary stays in the lower zone")
    func oneBelowABoundaryStaysDown() {
        let entries = [interval(360, at: 15.0, bpm: 157)]

        #expect(line(entries, zone: 3).points.map(\.duration) == [360])
        #expect(line(entries, zone: 4).points.isEmpty)
    }

    @Test("Peak heart rate is never read")
    func peakIsIgnored() {
        // Averaged Z3, peaked in Z5.
        let entries = [interval(360, at: 14.0, bpm: 150, peak: 185)]

        #expect(line(entries, zone: 3).points.map(\.duration) == [360])
        #expect(line(entries, zone: 5).points.isEmpty)
    }

    @Test("Only a valid interval joins a line")
    func onlyValidIntervalsJoin() {
        let entries = [
            Entry(reps: 5, weight: 100, date: date(day: 0)),
            Entry(duration: 360, intensity: 15.0, averageHeartRate: 0, date: date(day: 0)),
            Entry(duration: 360, intensity: 0, averageHeartRate: 160, date: date(day: 0)),
            interval(360, at: 15.0, bpm: 160),
        ]

        #expect(line(entries, zone: 4).points.map(\.entryCount) == [1])
        #expect(line(entries, zone: 1).points.isEmpty)
    }

    // MARK: - Exact duration

    @Test("A 6:02 is its own point and never joins 6:00")
    func durationsGroupExactlyAsTyped() {
        let entries = [
            interval(360, at: 15.0, bpm: 160),
            interval(362, at: 16.0, bpm: 160),
        ]

        let points = line(entries, zone: 4).points
        #expect(points.map(\.duration) == [360, 362])
        #expect(points.map(\.intensity) == [15.0, 16.0])
    }

    // MARK: - The ten-visit window

    @Test("An 11th visit pushes the oldest out of the window")
    func anEleventhVisitPushesTheOldestOut() throws {
        // Day 0 at 10.0 km/h, days 1–10 at 15.0: the 10.0 is out.
        let entries = [interval(360, at: 10.0, bpm: 160, day: 0)]
            + (1...10).map { interval(360, at: 15.0, bpm: 160, day: $0) }

        let point = try #require(line(entries, zone: 4).points.first)
        #expect(point.intensity == 15.0)
        #expect(point.entryCount == 10)
    }

    @Test("Five reps on one day are one visit")
    func fiveRepsInADayAreOneVisit() throws {
        // Ten one-rep visits, then a day of five reps. As visits, the window is the
        // five plus days 1–9: 14 entries. As entries, it would be 10.
        let entries = (0...9).map { interval(360, at: 14.0, bpm: 160, day: $0) }
            + (0..<5).map { interval(360, at: 15.0, bpm: 160, day: 10, minute: $0 * 8) }

        let point = try #require(line(entries, zone: 4).points.first)
        #expect(point.entryCount == 14)
    }

    @Test("Each duration counts its own visits")
    func eachDurationHasItsOwnWindow() throws {
        // Twelve days of 3:00 never push the one 6:00 out.
        let entries = [interval(360, at: 14.0, bpm: 160, day: 0)]
            + (1...12).map { interval(180, at: 16.0, bpm: 165, day: $0) }

        let points = line(entries, zone: 4).points
        #expect(points.map(\.duration) == [180, 360])
        #expect(points.map(\.entryCount) == [10, 1])
    }

    @Test("The window never moves with time alone")
    func theWindowNeverMovesWithTime() throws {
        // Nothing logged for over two years: the line still says what you last held.
        let entries = [interval(360, at: 10.0, bpm: 160, day: -900)]
            + (1...10).map { interval(360, at: 15.0, bpm: 160, day: -900 + $0) }

        let point = try #require(line(entries, zone: 4).points.first)
        #expect(point.entryCount == 10)
        #expect(point.intensity == 15.0)
    }

    // MARK: - The window's cut-off

    @Test("The cut-off is the start of the oldest visit in the window")
    func theCutOffIsTheOldestVisitInTheWindow() {
        let entries = (0...11).map { interval(360, at: 15.0, bpm: 160, day: $0) }

        let line = line(entries, zone: 4)
        #expect(line.cutOff(at: 360) == calendar.startOfDay(for: date(day: 2)))
    }

    @Test("Every entry in a visit sits above the cut-off, whatever its time of day")
    func aWholeVisitIsAboveTheCutOff() throws {
        let entries = (0...9).map { interval(360, at: 15.0, bpm: 160, day: $0, minute: 600) }
            + [interval(360, at: 15.0, bpm: 160, day: 0, minute: -600)]

        let cutOff = try #require(line(entries, zone: 4).cutOff(at: 360))
        #expect(entries.allSatisfy { $0.date >= cutOff })
    }

    @Test("A duration you have not done in this zone has no cut-off")
    func noCutOffWithoutAPoint() {
        let entries = [interval(360, at: 15.0, bpm: 160)]

        #expect(line(entries, zone: 4).cutOff(at: 362) == nil)
        #expect(line(entries, zone: 3).cutOff(at: 360) == nil)
    }

    // MARK: - Per-unit means, in steps

    @Test("A speed's mean is rounded to the nearest tenth")
    func speedMeanInTenths() throws {
        let entries = [15.0, 15.1, 15.1].map { interval(360, at: $0, bpm: 160) }

        let point = try #require(line(entries, unit: .speed, zone: 4).points.first)
        #expect(point.intensity == 15.1)   // 15.0666…
    }

    @Test("Watts are averaged as they are and rounded to a whole watt")
    func wattsMeanInWholeWatts() throws {
        let entries = [200.0, 201, 201].map { interval(360, at: $0, bpm: 160) }

        let point = try #require(line(entries, unit: .watts, zone: 4).points.first)
        #expect(point.intensity == 201)   // 200.666…
    }

    @Test("A split is averaged through 1/split³ and back, in tenths")
    func splitMeanThroughTheCube() throws {
        // 1:40 and 1:50 per 500 m: through the cube 104.525…, where a plain mean is 105.0.
        let entries = [100.0, 110].map { interval(360, at: $0, bpm: 160) }

        let point = try #require(line(entries, unit: .split, zone: 4).points.first)
        #expect(point.intensity == 104.5)
    }

    @Test("A level is averaged and rounded to a whole level")
    func levelMeanInWholeLevels() throws {
        let entries = [5.0, 5, 6].map { interval(360, at: $0, bpm: 160) }

        let point = try #require(line(entries, unit: .level, zone: 4).points.first)
        #expect(point.intensity == 5)   // 5.333…
    }

    @Test("A point carries its mean heart rate, rounded to a whole bpm")
    func meanHeartRateInWholeBpm() throws {
        let entries = [160, 161, 161].map { interval(360, at: 15.0, bpm: $0) }

        let point = try #require(line(entries, zone: 4).points.first)
        #expect(point.averageHeartRate == 161)   // 160.666…
        #expect(point.entryCount == 3)
    }

    // MARK: - Incline

    @Test("Inclines never mix on a speed erg")
    func inclinesNeverMix() {
        let entries = [
            interval(360, at: 15.0, bpm: 160, incline: 1),
            interval(360, at: 16.0, bpm: 160, incline: 0),
            interval(180, at: 17.0, bpm: 160, incline: 0.5),
        ]

        #expect(line(entries, zone: 4, incline: 1).points.map(\.intensity) == [15.0])
        #expect(line(entries, zone: 4, incline: 0).points.map(\.intensity) == [16.0])
        #expect(line(entries, zone: 4, incline: 0.5).points.map(\.duration) == [180])
        #expect(line(entries, zone: 4, incline: 2).points.isEmpty)
    }

    @Test("Incline is not read on an erg that is not a speed erg")
    func inclineIsIgnoredOffSpeed() {
        // A stray incline on a rower's rows never splits its line.
        let entries = [
            interval(360, at: 200, bpm: 160, incline: 0),
            interval(360, at: 210, bpm: 160, incline: 1),
        ]

        #expect(line(entries, unit: .watts, zone: 4, incline: 0).points.map(\.entryCount) == [2])
    }

    // MARK: - Drawn as it comes out

    @Test("A point out of physiological order is kept as it is")
    func outOfOrderPointsAreKept() {
        // A longer rep held faster than a shorter one: shown, not corrected.
        let entries = [
            interval(180, at: 14.0, bpm: 160),
            interval(360, at: 15.0, bpm: 160),
            interval(600, at: 14.5, bpm: 160),
        ]

        let points = line(entries, zone: 4).points
        #expect(points.map(\.duration) == [180, 360, 600])
        #expect(points.map(\.intensity) == [14.0, 15.0, 14.5])
    }

    @Test("A zone you have never landed in has no points")
    func anUnvisitedZoneHasNoLine() {
        let entries = [interval(360, at: 15.0, bpm: 175)]

        #expect(line(entries, zone: 4).points.isEmpty)
        #expect(line(entries, zone: 5).points.count == 1)
    }

    @Test("No zones means no line")
    func noZonesNoLine() {
        let entries = [interval(360, at: 15.0, bpm: 160)]
        let line = ZoneLine(entries: entries, zones: nil, unit: .speed, zone: 4, incline: 0, calendar: calendar)

        #expect(line.points.isEmpty)
        #expect(line.cutOff(at: 360) == nil)
        #expect(line.entriesOverTheAxis.isEmpty)
    }

    // MARK: - Over 20:00

    @Test("An entry over 20:00 is kept off the line but can still be found")
    func entriesOverTwentyMinutesAreNotDrawn() {
        let entries = [
            interval(1200, at: 13.0, bpm: 160, day: 0),
            interval(1201, at: 12.5, bpm: 160, day: 1),
            interval(3600, at: 12.0, bpm: 160, day: 2),
            interval(3600, at: 12.0, bpm: 150, day: 3),
        ]

        let line = line(entries, zone: 4)
        #expect(line.points.map(\.duration) == [1200])
        #expect(line.entriesOverTheAxis.map(\.duration) == [3600, 1201])   // newest first
    }

    @Test("A zone whose only entries are over 20:00 has no points, only the caption's entries")
    func onlyOverTwentyMinutes() {
        let entries = [interval(3600, at: 12.0, bpm: 160)]

        let line = line(entries, zone: 4)
        #expect(line.points.isEmpty)
        #expect(line.entriesOverTheAxis.count == 1)
    }

    @Test("Entries over 20:00 at another incline are not this line's")
    func overTwentyMinutesKeepsToItsIncline() {
        let entries = [interval(3600, at: 12.0, bpm: 160, incline: 1)]

        #expect(line(entries, zone: 4, incline: 0).entriesOverTheAxis.isEmpty)
    }

    // MARK: - Every zone's line

    @Test("Each zone gets its own line from the same entries")
    func eachZonesLine() {
        let entries = [
            interval(360, at: 13.0, bpm: 145),
            interval(360, at: 15.0, bpm: 160),
            interval(180, at: 17.0, bpm: 172),
        ]

        let lines = ZoneLine.lines(entries: entries, zones: zones, unit: .speed, incline: 0, calendar: calendar)
        #expect(lines.keys.sorted() == [1, 2, 3, 4, 5])
        #expect(lines[1]?.points.isEmpty == true)
        #expect(lines[2]?.points.isEmpty == true)
        #expect(lines[3]?.points.map(\.intensity) == [13.0])
        #expect(lines[4]?.points.map(\.intensity) == [15.0])
        #expect(lines[5]?.points.map(\.duration) == [180])
    }

    @Test("Without zones every zone's line is empty")
    func eachZonesLineWithoutZones() {
        let entries = [interval(360, at: 15.0, bpm: 160)]

        let lines = ZoneLine.lines(entries: entries, zones: nil, unit: .speed, incline: 0, calendar: calendar)
        #expect(lines.values.allSatisfy { $0.points.isEmpty })
    }

    // MARK: -

    private func line(
        _ entries: [Entry],
        unit: ErgUnit = .speed,
        zone: Int,
        incline: Double = 0
    ) -> ZoneLine {
        ZoneLine(entries: entries, zones: zones, unit: unit, zone: zone, incline: incline, calendar: calendar)
    }

    /// A valid interval on `day` days after a fixed start, at noon UTC.
    private func interval(
        _ duration: Int,
        at intensity: Double,
        bpm: Int,
        peak: Int? = nil,
        incline: Double = 0,
        day: Int = 0,
        minute: Int = 0
    ) -> Entry {
        Entry(
            duration: duration,
            intensity: intensity,
            incline: incline,
            averageHeartRate: bpm,
            peakHeartRate: peak ?? bpm + 5,
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

/// Four lower bounds, Z2 to Z5, read as `HeartRateZones` reads them: on a boundary is up.
private struct Bounds: ZoneMembership {
    let z2: Int, z3: Int, z4: Int, z5: Int

    func zone(of heartRate: Int) -> Int {
        1 + [z2, z3, z4, z5].filter { heartRate >= $0 }.count
    }
}
