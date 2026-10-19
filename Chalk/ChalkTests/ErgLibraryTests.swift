import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The endurance library's last entries: the erg tiles, the resume card, and the two
/// doors into the lap-list sheet — *Log again* and the erg detail screen's Log
/// (SPEC §13.5, §13.7).
///
/// The rules an implementer gets subtly wrong: **a tile leaves the heart rates out and
/// the card carries them** (`6:00 at 15.0 km/h · today` against the written form in
/// full), **incline is left out at 0 %**, and **the last entry is the last valid
/// interval** — a zeroed row neither writes a line nor floats a tile.
@Suite("Erg library")
struct ErgLibraryTests {

    // MARK: - The written form

    @Test("A tile shows the last entry without heart rates or pace")
    func aTileLeavesOutTheHeartRates() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 15.0, incline: 1, average: 168, peak: 174)
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 220, average: 150, peak: 158, on: .days(ago: 1))
        fixture.erg("Rower", unit: .split, kind: .freeWeight)
        try fixture.save()

        let tiles = try endurance(fixture).tiles

        #expect(tiles.map { $0.subtitle()?.decimalPoint } == [
            "6:00 at 15.0 km/h · 1 % · today",
            "10:00 at 220 W · yesterday",
            nil,
        ])
    }

    @Test("The resume card writes the last entry in full, for every unit")
    func theResumeCardWritesEveryUnit() throws {
        let cases: [(ErgUnit, Int, Double, Double, String)] = [
            (.speed, 360, 15.0, 1, "6:00 at 15.0 km/h (4:00 /km) · 1 % · 168/174 bpm · today"),
            (.speed, 360, 12.5, 0, "6:00 at 12.5 km/h (4:48 /km) · 168/174 bpm · today"),
            (.watts, 600, 220, 0, "10:00 at 220 W · 168/174 bpm · today"),
            (.split, 240, 107.5, 0, "4:00 at 1:47.5 /500 m · 168/174 bpm · today"),
            (.split, 240, 105, 0, "4:00 at 1:45 /500 m · 168/174 bpm · today"),
            (.level, 4200, 12, 0, "1:10:00 at Level 12 · 168/174 bpm · today"),
        ]
        for (unit, duration, intensity, incline, written) in cases {
            let fixture = try LibraryFixture()
            let erg = fixture.erg("Erg", unit: unit, kind: .freeWeight)
            fixture.interval(erg, duration: duration, intensity: intensity, incline: incline, average: 168, peak: 174)
            try fixture.save()

            let resume = try #require(try endurance(fixture).model.resume)

            #expect(resume.text().decimalPoint == written)
        }
    }

    @Test("The endurance card is the last erg logged anywhere, read off valid intervals")
    func theCardIsTheLastErgLogged() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        fixture.interval(rower, duration: 240, intensity: 110, average: 162, peak: 170, on: .days(ago: 2))
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 150, peak: 158, on: .days(ago: 3))
        // Newer, but no average heart rate: not something you did.
        fixture.interval(bike, duration: 600, intensity: 230, average: 0, peak: 0, on: .days(ago: 1))
        // A lift is strength's card, never endurance's.
        fixture.log(fixture.exercise("Squat"), reps: 5, weight: 100)
        try fixture.save()

        let (model, tiles) = try endurance(fixture)

        #expect(model.resume?.exercise === rower)
        #expect(tiles.map(\.name) == ["Rower", "BikeErg"])
    }

    // MARK: - The card's ring

    @Test("A transferable erg's goal rings the endurance card, filled from where you stood when it was set")
    func aTransferableErgsGoalRingsTheCard() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, intensity: 14.0, on: .days(ago: 10))
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 16.0, incline: 0, at: .days(ago: 5))
        fixture.interval(treadmill, intensity: 16.0, on: .now)
        try fixture.save()

        let resume = try #require(try endurance(fixture).model.resume)

        // The point is the mean of 14.0 and 16.0: halfway from 14.0 to 16.0.
        #expect(resume.ring == LibraryResume.Ring(progress: 0.5, isReached: false))
    }

    @Test("A gym-bound erg's card rings the goal of the machine the last entry was logged on")
    func aGymBoundCardRingsTheResumedMachine() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .split)
        let home = fixture.machine(for: rower, at: fixture.gym("Home"))
        let holiday = fixture.machine(for: rower, at: fixture.gym("Holiday"))
        GoalScope.machine(home).set(zone: 4, duration: 240, intensity: 100, incline: nil, at: .days(ago: 20))
        GoalScope.machine(holiday).set(zone: 4, duration: 240, intensity: 110, incline: nil, at: .days(ago: 20))
        fixture.interval(rower, machine: home, duration: 240, intensity: 102, on: .days(ago: 3))
        fixture.interval(rower, machine: holiday, duration: 240, intensity: 108, on: .now)
        try fixture.save()

        let resume = try #require(try endurance(fixture).model.resume)

        // The holiday rower's goal, reached there — never the home rower's, still open.
        #expect(resume.enduranceGoal?.intensity == 110)
        #expect(resume.ring == LibraryResume.Ring(progress: 1, isReached: true))
    }

    @Test("A goal on a sibling machine never rings the endurance card")
    func aSiblingMachinesGoalNeverRingsTheCard() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .split)
        let home = fixture.machine(for: rower, at: fixture.gym("Home"))
        let holiday = fixture.machine(for: rower, at: fixture.gym("Holiday"))
        GoalScope.machine(home).set(zone: 4, duration: 240, intensity: 100, incline: nil, at: .days(ago: 20))
        fixture.interval(rower, machine: home, duration: 240, intensity: 102, on: .days(ago: 3))
        fixture.interval(rower, machine: holiday, duration: 240, intensity: 108, on: .now)
        try fixture.save()

        let resume = try #require(try endurance(fixture).model.resume)

        #expect(resume.ring == nil)
    }

    @Test("An erg with no goal leaves the endurance card's ring empty")
    func noGoalNoRing() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        fixture.interval(fixture.erg("Treadmill", kind: .freeWeight))
        try fixture.save()

        let resume = try #require(try endurance(fixture).model.resume)

        #expect(resume.ring == nil)
    }

    // MARK: - Into the sheet

    @Test("Log again opens the lap list seeded from the card's entry, and Save moves the card")
    func logAgainSeedsFromTheCard() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        fixture.interval(rower, duration: 240, intensity: 110, average: 162, peak: 170, on: .days(ago: 2))
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 150, peak: 158, on: .days(ago: 3))
        try fixture.save()
        let (model, _) = try endurance(fixture)
        let resume = try #require(model.resume)

        let sheet = try #require(model.lapList(for: resume.exercise))

        #expect(sheet.drawn == ["4:00 | 1:50 | 162 | 170"])

        let other = try #require(model.lapList(for: bike))
        other.save()

        #expect(model.resume?.exercise === bike)
        #expect(model.resume?.text() == "10:00 at 210 W · 150/158 bpm · today")
    }

    @Test("A lift has no lap list")
    func aLiftHasNoLapList() throws {
        let fixture = try LibraryFixture()
        let squat = fixture.exercise("Squat")

        #expect(fixture.libraryModel().lapList(for: squat) == nil)
    }

    @Test("The erg detail screen's Log opens the lap list, and Save puts the screen and the library back in step")
    func theDetailLogOpensTheLapList() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 164, peak: 170, on: .days(ago: 3))
        try fixture.save()
        let library = fixture.libraryModel()
        library.show(.endurance)
        let detail = fixture.ergDetailModel(for: bike, refreshing: library)
        #expect(detail.entryCount == 1)

        let sheet = try #require(detail.logSheet())
        // The zones reach the sheet through the same defaults the library holds.
        #expect(sheet.line == .zone("Z4 · 158–169 bpm"))
        sheet.addRow()
        sheet.save()

        #expect(detail.entryCount == 3)
        #expect(detail.canChangeUnit == false)
        #expect(library.resume?.text() == "10:00 at 210 W · 164/170 bpm · today")
    }

    // MARK: - Helpers

    /// The endurance half's library, and its tiles — all Ungrouped here, so in recency order.
    private func endurance(_ fixture: LibraryFixture) throws -> (model: LibraryModel, tiles: [LibraryTile]) {
        let model = fixture.libraryModel()
        model.show(.endurance)
        guard case .grid(let sections) = model.content else {
            Issue.record("Expected the grid")
            return (model, [])
        }
        return (model, sections.flatMap(\.tiles))
    }
}
