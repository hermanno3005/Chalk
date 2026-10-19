import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The endurance goal sheet (SPEC §13.10): a short form — zone, duration, incline on a
/// speed erg, intensity — seeded from the point you scrubbed to, with the intensity blank
/// and the keypad up, a live line under it, and *Set goal* / *Clear goal*.
///
/// The rules an implementer gets subtly wrong: **the live line reads the exact point the
/// rows name**, never a nearby one, and says `Not held yet` rather than a gap from zero;
/// and **no goal can be named before zones are set**, nor on a gym-bound erg with no
/// machine.
@Suite("Endurance goal sheet model")
struct EnduranceGoalSheetModelTests {

    // MARK: - Seeding

    @Test("Zone, duration and incline seed from the scrubbed point; intensity opens blank with the keypad on it")
    func seedsFromTheSelection() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 600, intensity: 12.0, incline: 1, average: 150, on: .days(ago: 2))
        fixture.interval(treadmill, duration: 360, intensity: 15.0, incline: 1, average: 164, on: .days(ago: 1))
        try fixture.save()
        let detail = fixture.ergDetailModel(for: treadmill)
        detail.select(zone: 3)

        let sheet = try #require(detail.goalSheet())

        #expect(sheet.zone == 3)
        #expect(sheet.text(.duration) == "10:00")
        #expect(sheet.text(.incline) == "1")
        #expect(sheet.text(.intensity) == "")
        #expect(sheet.focus == .intensity)
        #expect(sheet.rows == [.duration, .incline, .intensity])
    }

    @Test("Off speed there is no incline row")
    func noInclineRowOffSpeed() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 360, intensity: 260, average: 164)
        try fixture.save()

        let sheet = try #require(fixture.ergDetailModel(for: rower).goalSheet())

        #expect(sheet.rows == [.duration, .intensity])
    }

    @Test("With nothing scrubbed, the rows open blank and the keypad on the first of them")
    func nothingToSeedFrom() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        try fixture.save()

        let sheet = try #require(fixture.ergDetailModel(for: treadmill).goalSheet())

        #expect(sheet.zone == nil)
        #expect(sheet.text(.duration) == "")
        #expect(sheet.focus == .duration)
    }

    // MARK: - The live line

    @Test("A goal above the point says by how much, in the unit's step")
    func theLineAbove() throws {
        let (fixture, treadmill) = try treadmillAt15_1()
        let sheet = try #require(fixture.ergDetailModel(for: treadmill).goalSheet())

        #expect(sheet.line == nil)   // nothing typed: nothing to compare

        sheet.type("15.5")

        let line = try #require(sheet.line)
        #expect(line.text.decimalPoint == "0.4 km/h above your 6:00 in Z4")
        #expect(!line.isReached)
    }

    @Test("A goal at or below the point is already reached, in grey")
    func theLineAlreadyReached() throws {
        let (fixture, treadmill) = try treadmillAt15_1()
        let sheet = try #require(fixture.ergDetailModel(for: treadmill).goalSheet())

        sheet.type("15.1")

        let line = try #require(sheet.line)
        #expect(line.text.decimalPoint == "Already reached — your 6:00 in Z4 is 15.1 km/h")
        #expect(line.isReached)
    }

    @Test("A point with nothing held reads not held yet, whatever is typed")
    func theLineNotHeldYet() throws {
        let (fixture, treadmill) = try treadmillAt15_1()
        let sheet = try #require(fixture.ergDetailModel(for: treadmill).goalSheet())

        sheet.zone = 5
        #expect(sheet.line?.text == "Not held yet — 6:00 in Z5 · 0 %")

        sheet.type("16")
        #expect(sheet.line?.text == "Not held yet — 6:00 in Z5 · 0 %")
        #expect(sheet.line?.isReached == false)
    }

    @Test("The line reads the exact point the rows name: a longer duration is not held yet")
    func theLineReadsTheExactPoint() throws {
        let (fixture, treadmill) = try treadmillAt15_1()
        let sheet = try #require(fixture.ergDetailModel(for: treadmill).goalSheet())

        sheet.select(.duration)
        sheet.type("2500")

        #expect(sheet.line?.text == "Not held yet — 25:00 in Z4 · 0 %")
    }

    @Test("On a split the line counts seconds faster as above")
    func theLineOnASplit() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        fixture.interval(rower, duration: 360, intensity: 107, average: 164)
        try fixture.save()
        let sheet = try #require(fixture.ergDetailModel(for: rower).goalSheet())

        sheet.type("145")
        #expect(sheet.line?.text == "2 s above your 6:00 in Z4")

        sheet.type("⌫⌫⌫150")
        #expect(sheet.line?.text == "Already reached — your 6:00 in Z4 is 1:47 /500 m")
    }

    // MARK: - Set and Clear

    @Test("Set goal is enabled once every field is filled")
    func setGoalEnablement() throws {
        let (fixture, treadmill) = try treadmillAt15_1()
        let sheet = try #require(fixture.ergDetailModel(for: treadmill).goalSheet())
        #expect(!sheet.canSetGoal)

        sheet.type("0")
        #expect(!sheet.canSetGoal)
        sheet.type("⌫15.5")
        #expect(sheet.canSetGoal)

        // A blank incline on a speed erg is no goal; 0 % is a value.
        sheet.select(.incline)
        sheet.type("⌫")
        #expect(!sheet.canSetGoal)
        sheet.type("0")
        #expect(sheet.canSetGoal)

        sheet.select(.duration)
        sheet.type("⌫")
        #expect(!sheet.canSetGoal)
    }

    @Test("Set goal is never enabled with no zone chosen")
    func setGoalNeedsAZone() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        try fixture.save()
        let sheet = try #require(fixture.ergDetailModel(for: rower).goalSheet())

        sheet.type("600")
        sheet.select(.intensity)
        sheet.type("260")
        #expect(!sheet.canSetGoal)

        sheet.zone = 3
        #expect(sheet.canSetGoal)
    }

    @Test("Setting a goal writes it on the scope in view, and the detail screen's line reads it")
    func settingAGoal() throws {
        let (fixture, treadmill) = try treadmillAt15_1()
        let detail = fixture.ergDetailModel(for: treadmill)
        let sheet = try #require(detail.goalSheet())

        sheet.type("15.5")
        sheet.setGoal()

        let relaunched = try fixture.afterRelaunch().fetch(FetchDescriptor<Exercise>())
        #expect(relaunched.first?.goalZone == 4)
        #expect(relaunched.first?.goalDuration == 360)
        #expect(relaunched.first?.goalIntensity == 15.5)
        #expect(relaunched.first?.goalIncline == 0)
        #expect(detail.goalLine?.text.decimalPoint == "Goal 15.5 km/h · 6:00 in Z4 · 0 % · 0.4 km/h to go")
        #expect(detail.goalMenuLabel == "Change goal…")
    }

    @Test("A goal over 20:00 can be set, and reads not held yet")
    func aGoalOverTwentyMinutesIsValid() throws {
        let (fixture, treadmill) = try treadmillAt15_1()
        let detail = fixture.ergDetailModel(for: treadmill)
        let sheet = try #require(detail.goalSheet())

        sheet.select(.duration)
        sheet.type("3000")
        sheet.select(.intensity)
        sheet.type("12")
        #expect(sheet.canSetGoal)
        sheet.setGoal()

        #expect(detail.goalLine?.text.decimalPoint == "Goal 12.0 km/h · 30:00 in Z4 · 0 % · not held yet")
    }

    @Test("Clear goal is offered only with a goal, and clears it with no confirmation")
    func clearingAGoal() throws {
        let (fixture, treadmill) = try treadmillAt15_1()
        let detail = fixture.ergDetailModel(for: treadmill)
        #expect(try #require(detail.goalSheet()).hasGoal == false)

        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 15.5, incline: 0)
        try fixture.save()
        detail.refresh()
        let sheet = try #require(detail.goalSheet())
        #expect(sheet.hasGoal)

        sheet.clearGoal()

        #expect(detail.goalLine == nil)
        let relaunched = try fixture.afterRelaunch().fetch(FetchDescriptor<Exercise>())
        #expect(relaunched.first?.goalZone == nil)
        #expect(relaunched.first?.goalSetAt == nil)
    }

    // MARK: - Gates

    @Test("No goal can be named before zones are set")
    func theZonesGate() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill)
        try fixture.save()
        let detail = fixture.ergDetailModel(for: treadmill)

        #expect(detail.goalMenuLabel == nil)
        #expect(detail.goalSheet() == nil)

        fixture.zones(117, 140, 158, 170)
        detail.refresh()
        #expect(detail.goalMenuLabel == "Set a goal…")
        #expect(detail.goalSheet() != nil)
    }

    @Test("A gym-bound erg with no machine gets no goal")
    func noMachineNoGoal() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        try fixture.save()
        let detail = fixture.ergDetailModel(for: treadmill)

        #expect(detail.goalMenuLabel == nil)
        #expect(detail.goalSheet() == nil)
    }

    // MARK: -

    /// A transferable treadmill whose 6:00 in Z4 at 0 % stands at 15.1 km/h.
    private func treadmillAt15_1() throws -> (LibraryFixture, Exercise) {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 15.1, incline: 0, average: 164)
        try fixture.save()
        return (fixture, treadmill)
    }
}

extension EnduranceGoalSheetModel {
    /// Types `keys` on the keypad into the focused row: digits, `.` for the decimal key
    /// and `⌫` for delete.
    func type(_ keys: String) {
        for key in keys {
            switch key {
            case ".": type(TwoStageNumber.Key.decimal)
            case "⌫": type(TwoStageNumber.Key.delete)
            default: type(TwoStageNumber.Key.digit(key.wholeNumberValue!))
            }
        }
    }
}
