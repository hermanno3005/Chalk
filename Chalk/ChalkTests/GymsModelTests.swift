import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The gyms model and the current gym (SPEC §7.4, §3). The current gym is a UUID in
/// `@AppStorage`, so the state an implementer forgets is the stale one: a UUID naming a
/// gym that is no longer there resolves to *no gym selected*, not to a crash and not to
/// a repair.
@Suite("Gyms model")
struct GymsModelTests {

    @Test("Nothing is selected until something is")
    func noGymIsSelectedByDefault() throws {
        let fixture = try LibraryFixture()
        fixture.gym("Fitness X")

        #expect(fixture.gymsModel().currentGym == nil)
    }

    @Test("The current gym is remembered by id, so a rename costs nothing")
    func theCurrentGymSurvivesARename() throws {
        let fixture = try LibraryFixture()
        let gym = fixture.gym("Fitness X")
        let model = fixture.gymsModel()
        model.select(gym)

        gym.name = "Fitness X Kreuzberg"
        model.refresh()

        #expect(model.currentGym === gym)
        #expect(model.currentGym?.name == "Fitness X Kreuzberg")
    }

    @Test("A stale id resolves to no gym selected")
    func aStaleIDResolvesToNothing() throws {
        let fixture = try LibraryFixture()
        fixture.defaults.set(UUID().uuidString, forKey: GymsModel.currentGymKey)

        #expect(fixture.gymsModel().currentGym == nil)
    }

    @Test("An archived gym is not somewhere you are standing")
    func anArchivedGymIsNotCurrent() throws {
        let fixture = try LibraryFixture()
        let gym = fixture.gym("Holiday Gym")
        let model = fixture.gymsModel()
        model.select(gym)

        gym.isArchived = true
        model.refresh()

        #expect(model.currentGym == nil)
    }

    @Test("The picker leaves out archived gyms and pins the current one")
    func thePickerOrdersByRecencyWithTheCurrentGymPinned() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let old = fixture.gym("Old Barn")
        let recent = fixture.gym("Fitness X")
        let archived = fixture.gym("Holiday Gym", isArchived: true)
        fixture.log(fixture.machine(for: exercise, at: old), reps: 5, weight: 60, on: .days(ago: 30))
        fixture.log(fixture.machine(for: exercise, at: recent), reps: 5, weight: 60, on: .days(ago: 1))
        fixture.log(fixture.machine(for: exercise, at: archived), reps: 5, weight: 60, on: .days(ago: 0))

        let model = fixture.gymsModel()
        #expect(model.gyms.map(\.name) == ["Fitness X", "Old Barn"])

        model.select(old)
        #expect(model.gyms.map(\.name) == ["Old Barn", "Fitness X"])
    }

    @Test("A gym created with no machines survives the sheet closing")
    func anEmptyGymIsHeldOnTheStore() throws {
        let fixture = try LibraryFixture()
        let model = fixture.gymsModel()

        let created = model.create(named: "  Fitness X  ")

        #expect(created?.name == "Fitness X")
        #expect(model.gyms.map(\.name) == ["Fitness X"])
        let reopened = try fixture.afterRelaunch()
        #expect(try reopened.fetch(FetchDescriptor<Gym>()).map(\.name) == ["Fitness X"])
    }

    @Test("A blank name is not a gym")
    func aBlankNameCreatesNothing() throws {
        let fixture = try LibraryFixture()
        let model = fixture.gymsModel()

        #expect(model.create(named: "   ") == nil)
        #expect(model.gyms.isEmpty)
    }

    @Test("A near name warns, archived gyms included")
    func aNearNameWarns() throws {
        let fixture = try LibraryFixture()
        let existing = fixture.gym("Fitness X")
        let archived = fixture.gym("Old Barn", isArchived: true)
        let model = fixture.gymsModel()

        #expect(model.nearMatch(for: "fitness x") === existing)
        #expect(model.nearMatch(for: "Old Barn") === archived)
        #expect(model.nearMatch(for: "Gorilla Gym") == nil)
    }
}
