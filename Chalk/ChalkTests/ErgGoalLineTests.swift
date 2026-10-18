import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The endurance goal on the erg detail screen (SPEC §13.10): the goal line under the
/// readout, the overflow's goal item, and the unit change that clears a goal and says so.
///
/// The rules an implementer gets subtly wrong: **the line shows whatever zone is
/// selected** — it is the goal's point, not the screen's — and **a scope never borrows
/// another machine's goal**.
@Suite("Erg goal line")
struct ErgGoalLineTests {

    @Test("No goal, no line")
    func noGoalNoLine() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill)
        try fixture.save()

        #expect(fixture.ergDetailModel(for: treadmill).goalLine == nil)
    }

    @Test("The goal line reads the goal's own point, whatever zone the screen shows")
    func theLineIgnoresTheSelection() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 15.1, incline: 1, average: 164)
        fixture.interval(treadmill, duration: 600, intensity: 12.0, incline: 1, average: 150)
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 15.5, incline: 1)
        try fixture.save()
        let detail = fixture.ergDetailModel(for: treadmill)

        detail.select(zone: 3)

        let line = try #require(detail.goalLine)
        #expect(line.text.decimalPoint == "Goal 15.5 km/h · 6:00 in Z4 · 1 % · 0.4 km/h to go")
        #expect(!line.isReached)
    }

    @Test("A reached goal stays, grey, with a full ring")
    func aReachedGoalStays() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let bike = fixture.erg("Bike", unit: .watts, kind: .freeWeight)
        GoalScope.exercise(bike).set(zone: 3, duration: 600, intensity: 260, incline: nil, at: .days(ago: 3))
        fixture.interval(bike, duration: 600, intensity: 265, average: 150)
        try fixture.save()

        let line = try #require(fixture.ergDetailModel(for: bike).goalLine)
        #expect(line.text == "Goal 260 W · 10:00 in Z3 · reached")
        #expect(line.isReached)
        #expect(line.progress == 1)
    }

    @Test("A machine's screen never borrows a sibling machine's goal")
    func noBorrowingAcrossMachines() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        let gym = fixture.gym("Fitness X")
        let withGoal = fixture.machine(for: treadmill, at: gym, label: "Technogym")
        let without = fixture.machine(for: treadmill, at: gym, label: "Life Fitness")
        fixture.interval(treadmill, machine: withGoal)
        fixture.interval(treadmill, machine: without)
        GoalScope.machine(withGoal).set(zone: 4, duration: 360, intensity: 15.5, incline: 0)
        try fixture.save()
        let detail = fixture.ergDetailModel(for: treadmill)

        detail.select(without)
        #expect(detail.goalLine == nil)
        #expect(detail.goalMenuLabel == "Set a goal…")

        detail.select(withGoal)
        #expect(detail.goalLine != nil)
    }

    // MARK: - Unit change

    @Test("Changing the unit clears the goal and names it")
    func aUnitChangeNamesTheGoal() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let bike = fixture.erg("Bike Erg", unit: .watts, kind: .freeWeight)
        GoalScope.exercise(bike).set(zone: 3, duration: 600, intensity: 260, incline: nil)
        try fixture.save()
        let detail = fixture.ergDetailModel(for: bike)

        detail.changeUnit(to: .level)

        #expect(detail.clearedGoalNotice == "Your goal of 260 W · 10:00 in Z3 is cleared.")
        #expect(detail.goalLine == nil)
        #expect(bike.goalZone == nil)
    }

    @Test("Changing the unit with no goal says nothing of one")
    func aUnitChangeWithNoGoal() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("Bike Erg", unit: .watts, kind: .freeWeight)
        try fixture.save()
        let detail = fixture.ergDetailModel(for: bike)

        detail.changeUnit(to: .level)

        #expect(detail.clearedGoalNotice == nil)
    }

    @Test("A gym-bound erg's unit change names the most recent machine goal and counts the rest")
    func aUnitChangeAcrossMachines() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let bike = fixture.erg("Bike Erg", unit: .watts)
        let gym = fixture.gym("Fitness X")
        let older = fixture.machine(for: bike, at: gym, label: "Wattbike")
        let newer = fixture.machine(for: bike, at: gym, label: "Keiser")
        GoalScope.machine(older).set(zone: 4, duration: 360, intensity: 300, incline: nil, at: .days(ago: 5))
        GoalScope.machine(newer).set(zone: 3, duration: 600, intensity: 260, incline: nil, at: .days(ago: 1))
        try fixture.save()
        let detail = fixture.ergDetailModel(for: bike)

        detail.changeUnit(to: .level)

        #expect(detail.clearedGoalNotice == "Your goal of 260 W · 10:00 in Z3 and 1 other goal are cleared.")
        #expect(older.goalZone == nil && newer.goalZone == nil)
    }
}
