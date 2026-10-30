import Foundation
import SwiftData
import Testing

@testable import Chalk

/// Reading a zone line on the erg detail screen (SPEC §13.8): the zone buttons, the
/// incline menu, the scrub readout, the over-20:00 caption, the zones gate and the empty
/// state, through `ErgDetailModel`.
///
/// The rules an implementer gets subtly wrong: **the selection snaps to durations you
/// have done and stays where the finger lifted** — `chartXSelection` writes nil on lift —
/// and **the scope is one machine's entries on a gym-bound erg**, every entry on a
/// transferable one.
@Suite("Erg readout")
struct ErgReadoutTests {

    // MARK: - The opening selection

    @Test("The screen opens on the zone, duration and incline of the most recent valid interval")
    func opensOnTheMostRecentInterval() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", unit: .speed, kind: .freeWeight)
        fixture.interval(treadmill, duration: 600, intensity: 12.0, incline: 0, average: 150, on: .days(ago: 3))
        fixture.interval(treadmill, duration: 360, intensity: 15.0, incline: 1, average: 164, on: .days(ago: 1))
        // Newer, but not a valid interval: no heart rate.
        fixture.interval(treadmill, duration: 120, intensity: 17.0, average: 0, peak: 0)
        try fixture.save()

        let model = fixture.ergDetailModel(for: treadmill)

        #expect(model.selection == .init(zone: 4, duration: 360, incline: 1))
        #expect(model.readout?.intensity.decimalPoint == "15.0 km/h")
        #expect(model.readout?.pace == "4:00 /km")
        // The aside beside the number, and the rows under the line (SPEC §13.8).
        #expect(model.readout?.aside == "6:00 in Z4")
        #expect(model.readout?.averageHeartRate == "164 bpm")
        #expect(model.readout?.entryCount == 1)
    }

    // MARK: - Scrubbing

    @Test("Scrubbing snaps to a duration you have done, the shorter of two equally near")
    func scrubbingSnapsToDurationsDone() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 180, intensity: 280, average: 165)
        fixture.interval(rower, duration: 360, intensity: 260, average: 165)
        fixture.interval(rower, duration: 600, intensity: 240, average: 165)
        try fixture.save()
        let model = fixture.ergDetailModel(for: rower)

        model.select(duration: 500)
        #expect(model.selection?.duration == 600)
        #expect(model.readout?.intensity == "240 W")

        // 4:30 is as near 3:00 as 6:00: nothing between two points is a number you held.
        model.select(duration: 270)
        #expect(model.selection?.duration == 180)
        #expect(model.readout?.aside == "3:00 in Z4")
        #expect(model.readout?.averageHeartRate == "165 bpm")
        #expect(model.readout?.entryCount == 1)
    }

    @Test("The selection stays where the finger lifted")
    func theSelectionIsSticky() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 180, intensity: 280, average: 165)
        fixture.interval(rower, duration: 600, intensity: 240, average: 165)
        try fixture.save()
        let model = fixture.ergDetailModel(for: rower)

        model.select(duration: 200)
        // chartXSelection clears its binding on lift.
        model.select(duration: nil)

        #expect(model.selection?.duration == 180)
        #expect(model.readout?.intensity == "280 W")
    }

    @Test("A new block keeps the screen where it was")
    func aWriteKeepsTheSelection() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 180, intensity: 280, average: 165, on: .days(ago: 1))
        fixture.interval(rower, duration: 600, intensity: 240, average: 165, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.ergDetailModel(for: rower)
        model.select(duration: 180)

        let sheet = try #require(model.logSheet())
        sheet.fill(0, "1000", "200", "150", "160")
        sheet.save()

        #expect(model.selection == .init(zone: 4, duration: 180, incline: 0))
    }

    // MARK: - The readout

    @Test("The readout is the point's mean intensity, mean heart rate and entry count")
    func theReadoutIsThePointsMean() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", unit: .speed, kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 14.0, average: 160, on: .days(ago: 3))
        fixture.interval(treadmill, duration: 360, intensity: 15.0, average: 164, on: .days(ago: 2))
        fixture.interval(treadmill, duration: 360, intensity: 16.0, average: 168, on: .days(ago: 1))
        try fixture.save()

        let readout = try #require(fixture.ergDetailModel(for: treadmill).readout)

        #expect(readout.intensity.decimalPoint == "15.0 km/h")
        #expect(readout.pace == "4:00 /km")
        #expect(readout.aside == "6:00 in Z4")
        #expect(readout.averageHeartRate == "164 bpm")
        #expect(readout.entryCount == 3)
    }

    @Test("Only a speed gets a pace row")
    func onlyASpeedHasAPace() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let skiErg = fixture.erg("SkiErg", unit: .split, kind: .freeWeight)
        fixture.interval(skiErg, duration: 240, intensity: 105, average: 150)
        let stairs = fixture.erg("Stairmaster", unit: .level, kind: .freeWeight)
        fixture.interval(stairs, duration: 600, intensity: 12, average: 130)
        try fixture.save()

        let split = try #require(fixture.ergDetailModel(for: skiErg).readout)
        #expect(split.intensity == "1:45 /500 m")
        #expect(split.pace == nil)
        #expect(split.aside == "4:00 in Z3")
        #expect(split.averageHeartRate == "150 bpm")
        #expect(split.entryCount == 1)

        let level = try #require(fixture.ergDetailModel(for: stairs).readout)
        #expect(level.intensity == "Level 12")
        #expect(level.pace == nil)
        #expect(level.aside == "10:00 in Z2")
        #expect(level.averageHeartRate == "130 bpm")
        #expect(level.entryCount == 1)
    }

    // MARK: - Zone tabs

    @Test("A zone tab moves the duration onto that zone's line")
    func aZoneSwitchSnapsTheDuration() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", unit: .speed, kind: .freeWeight)
        fixture.interval(treadmill, duration: 180, intensity: 16.5, average: 175, on: .days(ago: 2))
        fixture.interval(treadmill, duration: 360, intensity: 15.0, average: 164, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        model.select(zone: 5)

        #expect(model.selection == .init(zone: 5, duration: 180, incline: 0))
        #expect(model.readout?.intensity.decimalPoint == "16.5 km/h")
    }

    @Test("A zone with no line is dimmed but still tappable, and has no readout")
    func aZoneWithNoLineIsDimmed() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", unit: .speed, kind: .freeWeight)
        fixture.interval(treadmill, duration: 180, intensity: 16.5, average: 175, on: .days(ago: 2))
        fixture.interval(treadmill, duration: 360, intensity: 15.0, average: 164, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        #expect((1...5).filter(model.hasLine) == [4, 5])

        model.select(zone: 3)

        // The duration stays put: the no-line quotes read the one closest to it.
        #expect(model.selection == .init(zone: 3, duration: 360, incline: 0))
        #expect(model.readout == nil)
    }

    // MARK: - Scope

    @Test("A transferable erg reads every entry it has, wherever you are standing")
    func aTransferableErgReadsEverything() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let skiErg = fixture.erg("SkiErg", unit: .watts, kind: .freeWeight)
        fixture.interval(skiErg, duration: 360, intensity: 200, average: 150, on: .days(ago: 2))
        fixture.interval(skiErg, duration: 360, intensity: 210, average: 150, on: .days(ago: 1))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(fixture.gym("FitX"))

        let model = fixture.ergDetailModel(for: skiErg, gyms: gyms)

        #expect(model.readout?.intensity == "205 W")
        #expect(model.readout?.aside == "6:00 in Z3")
        #expect(model.readout?.averageHeartRate == "150 bpm")
        #expect(model.readout?.entryCount == 2)
    }

    @Test("A gym-bound erg reads the qualifier's machine, and nothing else")
    func aGymBoundErgReadsOneMachine() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        let atHome = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        let atAway = fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Matrix T7")
        fixture.interval(treadmill, machine: atHome, duration: 360, intensity: 15.0, average: 164, on: .days(ago: 1))
        fixture.interval(treadmill, machine: atAway, duration: 360, intensity: 13.5, average: 166, on: .days(ago: 2))
        fixture.interval(treadmill, machine: atAway, duration: 600, intensity: 13.0, average: 160, on: .days(ago: 3))
        try fixture.save()

        let model = fixture.ergDetailModel(for: treadmill)
        #expect(model.machine === atHome)
        #expect(model.readout?.aside == "6:00 in Z4")
        #expect(model.readout?.averageHeartRate == "164 bpm")
        #expect(model.readout?.entryCount == 1)

        model.select(atAway)

        // The same zone and duration, compared across machines.
        #expect(model.selection == .init(zone: 4, duration: 360, incline: 0))
        #expect(model.readout?.intensity.decimalPoint == "13.5 km/h")
        #expect(model.readout?.aside == "6:00 in Z4")
        #expect(model.readout?.averageHeartRate == "166 bpm")
        #expect(model.readout?.entryCount == 1)
    }

    // MARK: - The incline menu

    @Test("The incline menu offers every incline logged here, and switches lines")
    func theInclineMenuSwitchesLines() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", unit: .speed, kind: .freeWeight)
        fixture.interval(treadmill, duration: 600, intensity: 11.0, incline: 0, average: 150, on: .days(ago: 3))
        fixture.interval(treadmill, duration: 360, intensity: 15.0, incline: 0, average: 164, on: .days(ago: 2))
        fixture.interval(treadmill, duration: 360, intensity: 13.0, incline: 1.5, average: 164, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        #expect(model.inclines == [0, 1.5])
        #expect(model.selection?.incline == 1.5)
        #expect(model.readout?.intensity.decimalPoint == "13.0 km/h")
        #expect((1...5).filter(model.hasLine) == [4])

        model.select(incline: 0)

        // 15 km/h flat never answers for 15 km/h at 1.5 %.
        #expect(model.readout?.intensity.decimalPoint == "15.0 km/h")
        #expect((1...5).filter(model.hasLine) == [3, 4])
    }

    @Test("Only a speed erg has an incline menu")
    func onlyASpeedErgHasInclines() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let stairs = fixture.erg("Stairmaster", unit: .level, kind: .freeWeight)
        // An incline on a level erg is never read.
        fixture.interval(stairs, duration: 600, intensity: 12, incline: 2, average: 130, on: .days(ago: 2))
        fixture.interval(stairs, duration: 600, intensity: 14, incline: 0, average: 130, on: .days(ago: 1))
        try fixture.save()

        let model = fixture.ergDetailModel(for: stairs)

        #expect(model.inclines.isEmpty)
        #expect(model.readout?.intensity == "Level 13")
        #expect(model.readout?.aside == "10:00 in Z2")
        #expect(model.readout?.averageHeartRate == "130 bpm")
        #expect(model.readout?.entryCount == 2)
    }

    // MARK: - The zones gate

    @Test("Without zones there is no selection and no readout, and the entries join once zones are set")
    func theZonesGate() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", unit: .speed, kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 15.0, average: 164)
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        #expect(model.needsZones)
        #expect(!model.isEmpty)
        #expect(model.selection == nil)
        #expect(model.readout == nil)

        let settings = model.settings()
        settings.lowerBounds = [117, 140, 158, 170]
        settings.save()
        model.refresh()

        #expect(!model.needsZones)
        #expect(model.selection == .init(zone: 4, duration: 360, incline: 0))
        #expect(model.readout?.aside == "6:00 in Z4")
        #expect(model.readout?.averageHeartRate == "164 bpm")
        #expect(model.readout?.entryCount == 1)
    }

    // MARK: - Over 20:00

    @Test("Entries over 20:00 are counted under the line, by zone, and never drawn")
    func theOverTwentyCaptionCounts() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 360, intensity: 260, average: 164, on: .days(ago: 4))
        fixture.interval(rower, duration: 1500, intensity: 220, average: 160, on: .days(ago: 3))
        fixture.interval(rower, duration: 3600, intensity: 200, average: 162, on: .days(ago: 2))
        fixture.interval(rower, duration: 1800, intensity: 180, average: 150, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.ergDetailModel(for: rower)

        // The most recent is 30:00 in Z3, which has no point: the zone has no line, and
        // the caption is what is there.
        #expect(model.selection?.zone == 3)
        #expect(model.readout == nil)
        #expect(!model.hasLine(3))
        #expect(model.overTheAxisCaption == "1 entry over 20:00")

        model.select(zone: 4)
        #expect(model.selection?.duration == 360)
        #expect(model.readout?.aside == "6:00 in Z4")
        #expect(model.readout?.averageHeartRate == "164 bpm")
        #expect(model.readout?.entryCount == 1)
        #expect(model.overTheAxisCaption == "2 entries over 20:00")

        model.select(zone: 5)
        #expect(model.overTheAxisCaption == nil)
    }

    // MARK: - The empty state

    @Test("A machine with nothing logged is the empty state, however much its siblings hold")
    func anEmptyMachineIsTheEmptyState() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        let home = fixture.gym("Urban Gym")
        fixture.machine(for: treadmill, at: home, label: "Technogym Run")
        let atAway = fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Matrix T7")
        fixture.interval(treadmill, machine: atAway)
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(home)

        let model = fixture.ergDetailModel(for: treadmill, gyms: gyms)

        #expect(model.isEmpty)
        #expect(model.selection == nil)
        #expect(model.readout == nil)
        #expect(model.overTheAxisCaption == nil)
    }

    @Test("The first block on an empty erg opens the screen on it")
    func theFirstBlockOpensTheScreen() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let skiErg = fixture.erg("SkiErg", unit: .watts, kind: .freeWeight)
        try fixture.save()
        let model = fixture.ergDetailModel(for: skiErg)
        #expect(model.isEmpty)

        let sheet = try #require(model.logSheet())
        sheet.fill(0, "400", "250", "160", "168")
        sheet.save()

        #expect(!model.isEmpty)
        #expect(model.selection == .init(zone: 4, duration: 240, incline: 0))
        #expect(model.readout?.intensity == "250 W")
    }
}
