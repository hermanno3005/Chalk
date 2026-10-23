import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The distance unit (SPEC §15.2, ADR-0009): a speed erg's intensity is a plain number on
/// the scale chosen now, km/h with min/km or mph with min/mile, and every surface that
/// writes a speed writes that scale. Nothing converts at read time, so a library on miles
/// shows the very numbers it stores.
@Suite("Distance unit")
struct DistanceUnitTests {

    // MARK: - The phone's update

    @Test("A launch with no unit stored, over a library that isn't empty, stores km", arguments: [
        "an exercise", "an erg", "a gym",
    ])
    func aLaunchOverALibraryStoresKilometres(holding row: String) throws {
        let fixture = try LibraryFixture()
        switch row {
        case "an exercise": fixture.exercise("Squat")
        case "an erg": fixture.erg("Treadmill")
        default: fixture.gym("Fitness X")
        }
        try fixture.save()

        _ = fixture.libraryModel()

        #expect(DistanceUnit.stored(in: fixture.defaults) == .km)
    }

    @Test("A launch over an empty library leaves the unit unset, which reads as km")
    func aLaunchOverAnEmptyLibraryLeavesTheUnitUnset() throws {
        let fixture = try LibraryFixture()

        _ = fixture.libraryModel()

        #expect(DistanceUnit.stored(in: fixture.defaults) == nil)
        #expect(DistanceUnit(defaults: fixture.defaults) == .km)
    }

    @Test("A launch over a library already on a weight unit, from before distances, stores km beside it")
    func aLaunchAfterTheWeightUnitStoresKilometres() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.lb)
        fixture.erg("Treadmill")
        try fixture.save()

        _ = fixture.libraryModel()

        #expect(DistanceUnit.stored(in: fixture.defaults) == .km)
        #expect(WeightUnit.stored(in: fixture.defaults) == .lb)
    }

    @Test("A launch never touches a unit already stored")
    func aLaunchKeepsAStoredUnit() throws {
        let fixture = try LibraryFixture()
        fixture.distanceUnit(.mi)
        fixture.erg("Treadmill")
        try fixture.save()

        _ = fixture.libraryModel()

        #expect(DistanceUnit.stored(in: fixture.defaults) == .mi)
    }

    // MARK: - The screens, on miles

    @Test("On miles, the readout writes mph with its pace per mile")
    func theReadoutWritesMiles() throws {
        let (fixture, treadmill) = try treadmillOnMiles()

        let model = fixture.ergDetailModel(for: treadmill)

        #expect(model.readout?.intensity.decimalPoint == "9.3 mph")
        #expect(model.readout?.pace == "6:27 /mi")
    }

    @Test("On miles, the goal line writes mph, its gap included")
    func theGoalLineWritesMiles() throws {
        let (fixture, treadmill) = try treadmillOnMiles()
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 9.7, incline: 1)
        try fixture.save()

        let line = try #require(fixture.ergDetailModel(for: treadmill).goalLine)

        #expect(line.text.decimalPoint == "Goal 9.7 mph · 6:00 in Z4 · 1 % · 0.4 mph to go")
    }

    @Test("On miles, the no-line quotes write mph")
    func theNoLineQuotesWriteMiles() throws {
        let (fixture, treadmill) = try treadmillOnMiles()
        let model = fixture.ergDetailModel(for: treadmill)

        model.select(zone: 5)

        #expect(model.noLine?.quotes.map(\.text.decimalPoint) == ["Z4 6:00 at 9.3 mph — too easy"])
    }

    @Test("On miles, the machine hint writes mph")
    func theHintWritesMiles() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        fixture.distanceUnit(.mi)
        let treadmill = fixture.erg("Treadmill")
        let mcFit = fixture.gym("McFit")
        fixture.machine(for: treadmill, at: mcFit, label: "Life Fitness")
        let sibling = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        fixture.interval(treadmill, machine: sibling, duration: 360, intensity: 9.3, incline: 1, average: 164)
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(mcFit)

        let model = fixture.ergDetailModel(for: treadmill, gyms: gyms)

        #expect(model.hint?.emptyStateLine.decimalPoint
            == "No entries here — 6:00 in Z4 at 9.3 mph · 1 % on Technogym Run · Urban Gym")
    }

    @Test("On miles, the point's history rows write mph with the pace per mile")
    func theHistoryWritesMiles() throws {
        let (fixture, treadmill) = try treadmillOnMiles()

        let model = try #require(fixture.ergDetailModel(for: treadmill).historySheet())

        #expect(model.rows.map(\.intensity.decimalPoint) == ["9.3 mph (6:27 /mi)"])
    }

    @Test("On miles, the tile and the resume card write mph")
    func theLibraryWritesMiles() throws {
        let (fixture, _) = try treadmillOnMiles()

        let model = fixture.libraryModel()
        model.show(.endurance)

        #expect(model.resume?.text().decimalPoint == "6:00 at 9.3 mph (6:27 /mi) · 1 % · 164/170 bpm · today")
        guard case .grid(let sections) = model.content else {
            Issue.record("Expected the grid")
            return
        }
        #expect(sections[0].tiles[0].subtitle()?.decimalPoint == "6:00 at 9.3 mph · 1 % · today")
    }

    @Test("On miles, the lap list titles its speed column mph")
    func theLapListWritesMiles() throws {
        let (fixture, treadmill) = try treadmillOnMiles()

        let sheet = fixture.lapListModel(for: treadmill)

        #expect(sheet.columns.map { $0.columnTitle(sheet.unit, sheet.distanceUnit) } == ["Time", "mph", "%", "Avg", "Peak"])
    }

    @Test("On miles, the goal sheet's line writes mph")
    func theGoalSheetWritesMiles() throws {
        let (fixture, treadmill) = try treadmillOnMiles()
        let sheet = try #require(fixture.ergDetailModel(for: treadmill).goalSheet())

        sheet.type("9.7")
        #expect(sheet.line?.text.decimalPoint == "0.4 mph above your 6:00 in Z4")

        sheet.type("⌫⌫⌫9.3")
        #expect(sheet.line?.text.decimalPoint == "Already reached — your 6:00 in Z4 is 9.3 mph")
    }

    @Test("On miles, a kind change and a merge name a speed goal in mph")
    func theRepairsWriteMiles() throws {
        let (fixture, treadmill) = try treadmillOnMiles()
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 9.7, incline: 1)
        try fixture.save()

        // The sentence has a comma of its own, so the locale's decimal is written in.
        let ninePointSeven = "9\(WeightText.decimalSeparator)7"
        #expect(fixture.ergDetailModel(for: treadmill).kindChange.promptDetail
            == "Treadmill becomes gym-bound, and 1 entry and your goal of \(ninePointSeven) mph · 6:00 in Z4 · 1 % move to the machine you pick.")

        let rower = fixture.erg("Rower")
        let gym = fixture.gym("FitX")
        let loser = fixture.machine(for: rower, at: gym)
        let sibling = fixture.machine(for: rower, at: gym, label: "Technogym Excite")
        GoalScope.machine(loser).set(zone: 3, duration: 600, intensity: 8.0, incline: 0, at: .days(ago: 9))
        GoalScope.machine(sibling).set(zone: 4, duration: 360, intensity: 9.7, incline: 1, at: .days(ago: 2))
        #expect(MachineMerge(loser: loser, sibling: sibling, distanceUnit: .mi).question.decimalPoint
            == "Delete Unlabelled? Your goal of 9.7 mph · 6:00 in Z4 · 1 % is kept; 1 other goal is cleared.")
    }

    // MARK: - The words

    @Test("Pace is worked out per km or per mile, to the whole second", arguments: [
        (15.0, DistanceUnit.km, "4:00 /km"),
        (12.5, DistanceUnit.km, "4:48 /km"),
        (10.0, DistanceUnit.mi, "6:00 /mi"),
        // 3600 / 9.3 = 387.1 s, so 6:27.
        (9.3, DistanceUnit.mi, "6:27 /mi"),
        // 3600 / 7.7 = 467.5 s, which rounds up to 7:48.
        (7.7, DistanceUnit.mi, "7:48 /mi"),
    ])
    func pace(speed: Double, unit: DistanceUnit, expected: String) {
        #expect(EnduranceText.pace(speed, unit).decimalPoint == expected)
    }

    @Test("A speed is written in the unit, with its pace beside it or without")
    func intensity() {
        #expect(EnduranceText.intensity(9.3, .speed, .mi).decimalPoint == "9.3 mph (6:27 /mi)")
        #expect(EnduranceText.intensity(9.3, .speed, .mi, pace: false).decimalPoint == "9.3 mph")
        #expect(EnduranceText.intensity(15, .speed, .km).decimalPoint == "15.0 km/h (4:00 /km)")
        #expect(EnduranceText.goalIntensity(9.3, .speed, .mi).decimalPoint == "9.3 mph")
    }

    @Test("Watts, splits and levels have no scale, and read the same on miles")
    func unscaledUnits() {
        #expect(EnduranceText.intensity(220, .watts, .mi) == "220 W")
        #expect(EnduranceText.intensity(105, .split, .mi) == "1:45 /500 m")
        #expect(EnduranceText.goalIntensity(12, .level, .mi) == "L12")
    }

    @Test("A goal's distance to go is in the unit's own 0.1 step")
    func steps() {
        #expect(EnduranceText.steps(4, .speed, .mi).decimalPoint == "0.4 mph")
        #expect(EnduranceText.steps(4, .speed, .km).decimalPoint == "0.4 km/h")
        #expect(EnduranceText.steps(12, .watts, .mi) == "12 W")
    }

    @Test("The create-erg sheet offers a speed in the unit")
    func pickerTitle() {
        #expect(ErgUnit.speed.pickerTitle(.mi) == "Speed (mph)")
        #expect(ErgUnit.speed.pickerTitle(.km) == "Speed (km/h)")
        #expect(ErgUnit.watts.pickerTitle(.mi) == "Watts")
    }

    @Test("The lap list's speed column is titled in the unit")
    func columnTitle() {
        #expect(EnduranceField.intensity.columnTitle(.speed, .mi) == "mph")
        #expect(EnduranceField.intensity.columnTitle(.speed, .km) == "km/h")
        #expect(EnduranceField.intensity.columnTitle(.watts, .mi) == "W")
    }

    // MARK: -

    /// A transferable treadmill on miles whose 6:00 in Z4 at 1 % stands at 9.3 mph.
    private func treadmillOnMiles() throws -> (LibraryFixture, Exercise) {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        fixture.distanceUnit(.mi)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 9.3, incline: 1, average: 164, peak: 170)
        try fixture.save()
        return (fixture, treadmill)
    }
}
