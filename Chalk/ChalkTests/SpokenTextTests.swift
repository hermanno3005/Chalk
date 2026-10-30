import Foundation
import Testing

@testable import Chalk

/// What VoiceOver says where Chalk writes symbols (SPEC §15.6): every written form that
/// carries a `×`, a `·`, `bpm` or a unit has a spoken twin beside it, a sentence in
/// Chalk's words in the weight and distance unit.
@Suite("Spoken text")
struct SpokenTextTests {

    private let decimal = WeightText.decimalSeparator

    @Test("A lift is said as reps at a weight, in the weight unit")
    func aLift() {
        let lift = LastEntry(reps: 8, weight: 52.5, date: .now)

        #expect(lift.spokenLift(in: .kg) == "8 reps at 52\(decimal)5 kilograms")
        #expect(lift.spokenLift(in: .lb) == "8 reps at 52\(decimal)5 pounds")
        #expect(LastEntry(reps: 1, weight: 1, date: .now).spokenLift(in: .kg) == "1 rep at 1 kilogram")
    }

    @Test("A tile says what you last did, then the day")
    func aTileSubtitle() {
        let lift = LibraryTile(
            exercise: Exercise(name: "Bench Press"),
            lastEntry: LastEntry(reps: 8, weight: 100, date: .now),
            weightUnit: .lb,
            distanceUnit: .km
        )
        let erg = LibraryTile(
            exercise: Exercise(name: "Treadmill"),
            lastEntry: nil,
            lastInterval: LastInterval(
                unit: .speed, duration: 360, intensity: 9.3, incline: 1,
                averageHeartRate: 164, peakHeartRate: 170, date: .now
            ),
            weightUnit: .kg,
            distanceUnit: .mi
        )

        #expect(lift.subtitleParts()?.spoken == "8 reps at 100 pounds, today")
        #expect(erg.subtitleParts()?.spoken == "6 minutes at 9\(decimal)3 miles per hour, 1 percent incline, today")
    }

    @Test("The strength readout says the weight for the rep count, or that the cell is unproven")
    func theStrengthReadout() {
        let proven = ExerciseDetailModel.Readout(reps: 5, weight: 102.5, entriesBehind: 3, entriesInScope: 9, weightUnit: .lb)
        let unproven = ExerciseDetailModel.Readout(reps: 9, weight: nil, entriesBehind: 0, entriesInScope: 9, weightUnit: .lb)

        #expect(proven.spoken == "102\(decimal)5 pounds for 5 reps")
        #expect(unproven.spoken == "Not yet proven at 9 reps")
    }

    @Test("The erg readout says the intensity at its point, its pace and its heart rate in words")
    func theErgReadout() throws {
        // Z4 from 158 bpm: one 9.3 mph for 6:00 at 164 bpm.
        let zones = try #require(HeartRateZones(lowerBounds: [120, 140, 158, 170]))
        let reading = ErgReading(
            entries: [Entry(duration: 360, intensity: 9.3, incline: 0, averageHeartRate: 164, peakHeartRate: 170)],
            zones: zones,
            unit: .speed,
            distanceUnit: .mi,
            keeping: nil
        )

        let readout = try #require(reading.readout)
        #expect(readout.spoken == "9\(decimal)3 miles per hour for 6 minutes in zone 4")
        #expect(readout.spokenPace == "6 minutes 27 seconds per mile")
        #expect(readout.spokenHeartRate == "164 beats per minute")
    }

    @Test("A strength goal is said as a weight for reps, with what is left or that it is reached")
    func aStrengthGoal() throws {
        let entries = [Entry(reps: 5, weight: 145)]
        let reached = try #require(Goal(reps: 5, weight: 140, setAt: .now, entries: entries))
        let open = try #require(Goal(reps: 3, weight: 160, setAt: .now, entries: entries))

        #expect(reached.spokenLine(in: .lb) == "Goal 140 pounds for 5 reps, reached")
        #expect(open.spokenLine(in: .lb) == "Goal 160 pounds for 3 reps, 15 pounds to go")
    }

    @Test("An erg's goal line says its point in words, and what is left")
    func anErgGoalLine() throws {
        // Z3 from 140 bpm: one level 10 for 10:00 at 150 bpm, against a goal of level 12.
        let zones = try #require(HeartRateZones(lowerBounds: [120, 140, 158, 170]))
        let entries = [Entry(duration: 600, intensity: 10, averageHeartRate: 150, peakHeartRate: 156)]
        let goal = try #require(EnduranceGoal(
            zone: 3, duration: 600, intensity: 12, incline: nil, setAt: .now,
            entries: entries, zones: zones, unit: .level, distanceUnit: .km
        ))

        #expect(GoalLine(endurance: goal).spoken == "Goal level 12 for 10 minutes in zone 3, 2 levels to go")
    }

    @Test("A rep-max card's cell says its rep count, then its weight or that it is unproven")
    func aRepMaxCell() {
        #expect(RepMaxCard.Cell(reps: 5, weight: 95, weightUnit: .kg).spoken == "5 reps, 95 kilograms")
        #expect(RepMaxCard.Cell(reps: 1, weight: 225, weightUnit: .lb).spoken == "1 rep, 225 pounds")
        #expect(RepMaxCard.Cell(reps: 9, weight: nil, weightUnit: .kg).spoken == "9 reps, not yet proven")
    }

    @Test("A zone's heart rates are said in words", arguments: [
        (1, "below 120 beats per minute"),
        (4, "158 to 169 beats per minute"),
        (5, "170 beats per minute and up"),
    ])
    func aZoneRange(zone: Int, spoken: String) throws {
        let zones = try #require(HeartRateZones(lowerBounds: [120, 140, 158, 170]))

        #expect(zones.spokenRange(of: zone) == spoken)
    }

    @Test("The zone a heart rate falls in is said with its range")
    func aZoneLine() throws {
        let zones = try #require(HeartRateZones(lowerBounds: [120, 140, 158, 170]))

        #expect(zones.spokenZoneLine(of: 164) == "Zone 4, 158 to 169 beats per minute")
    }

    @Test("The resume card says the whole last interval, heart rates included, then the day")
    func theResumeCard() {
        let lift = LibraryResume(
            exercise: Exercise(name: "Bench Press"),
            lastEntry: LastEntry(reps: 8, weight: 52.5, date: .now),
            goal: nil,
            weightUnit: .kg,
            distanceUnit: .km
        )
        let interval = LastInterval(
            unit: .speed, duration: 360, intensity: 15, incline: 1,
            averageHeartRate: 168, peakHeartRate: 174, date: .now
        )

        #expect(lift.spoken() == "8 reps at 52\(decimal)5 kilograms, today")
        #expect(interval.spoken(in: .km) == "6 minutes at 15\(decimal)0 kilometres per hour, pace 4 minutes per kilometre, "
            + "1 percent incline, average 168, peak 174 beats per minute, today")
    }

    @Test("A grid cell's value is said in words, so a duration is never read as a time of day", arguments: [
        (EnduranceField.duration, ErgUnit.speed, 390.0, "6 minutes 30 seconds"),
        (.intensity, .speed, 9.5, "9DEC5 miles per hour"),
        (.intensity, .split, 105, "1 minute 45 seconds per 500 metres"),
        (.incline, .speed, 1.5, "1DEC5 percent"),
        (.averageHeartRate, .speed, 164, "164 beats per minute"),
        (.peakHeartRate, .watts, 170, "170 beats per minute"),
    ])
    func aGridCell(field: EnduranceField, unit: ErgUnit, value: Double, spoken: String) {
        #expect(EnduranceText.spokenCell(value, field, unit, .mi) == spoken.replacingOccurrences(of: "DEC", with: decimal))
    }

    // MARK: - History and hints

    @Test("A strength history row says its lift in words")
    func aStrengthHistoryRow() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 75)

        let model = fixture.historySheetModel(for: bench, atLeast: 5)

        #expect(model.rows.map(\.spokenLift) == ["5 reps at 75 kilograms"])
    }

    @Test("An erg history row says the day, the intensity, its pace and both heart rates in words")
    func anErgHistoryRow() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", unit: .speed, kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 15.0, incline: 1, average: 164, peak: 170, on: .days(ago: 1))
        try fixture.save()

        let model = try #require(fixture.ergDetailModel(for: treadmill).historySheet())

        #expect(model.rows.map(\.spoken) == [
            "yesterday, 15\(decimal)0 kilometres per hour, pace 4 minutes per kilometre, average 164, peak 170 beats per minute",
        ])
    }

    @Test("A strength machine hint says the sibling's weight for 5 reps in words")
    func aStrengthHint() {
        let hint = MachineHint(weight: 55, machineName: "Hammer Strength", weightUnit: .kg)

        #expect(hint.spokenEmptyStateLine == "No entries here. 55 kilograms for 5 reps on Hammer Strength")
    }

    @Test("An erg machine hint says the sibling's point in words")
    func anErgHint() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        let mcFit = fixture.gym("McFit")
        fixture.machine(for: treadmill, at: mcFit, label: "Life Fitness")
        let sibling = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        fixture.interval(treadmill, machine: sibling, duration: 360, intensity: 15.0, incline: 1, average: 164, on: .days(ago: 1))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(mcFit)

        let model = fixture.ergDetailModel(for: treadmill, gyms: gyms)

        #expect(model.hint?.spokenEmptyStateLine
            == "No entries here. 6 minutes in zone 4 at 15\(decimal)0 kilometres per hour, 1 percent incline, on Technogym Run at Urban Gym")
    }
}
