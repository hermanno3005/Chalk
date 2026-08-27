import Foundation
import Testing

@testable import Chalk

/// The app's one machine picker, as a value (SPEC §5.3, §6.4). It is flat and sectioned
/// by gym: picking a machine is one decision, never a gym followed by a machine.
@Suite("Machine menu")
struct MachineMenuTests {

    @Test("Sections order by gym recency, with the current gym first")
    func sectionsOrderByGymRecencyWithTheCurrentGymFirst() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let stale = fixture.gym("Holiday Gym")
        let recent = fixture.gym("Fitness X")
        let current = fixture.gym("Old Barn")
        let atStale = fixture.machine(for: exercise, at: stale, label: "Blue")
        let atRecent = fixture.machine(for: exercise, at: recent, label: "Green")
        let atCurrent = fixture.machine(for: exercise, at: current, label: "Rusty")
        fixture.log(atStale, reps: 5, weight: 60, on: .days(ago: 90))
        fixture.log(atRecent, reps: 5, weight: 60, on: .days(ago: 1))
        fixture.log(atCurrent, reps: 5, weight: 60, on: .days(ago: 40))

        let menu = MachineMenu(
            machines: [atStale, atRecent, atCurrent],
            currentGym: current
        )

        #expect(menu.sections.map(\.title) == ["Old Barn", "Fitness X", "Holiday Gym"])
    }

    @Test("A gym's machines order by recency within its section")
    func machinesOrderByRecencyWithinASection() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let older = fixture.machine(for: exercise, at: gym, label: "Plate loaded")
        let newer = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(older, reps: 5, weight: 60, on: .days(ago: 10))
        fixture.log(newer, reps: 5, weight: 60, on: .days(ago: 2))

        let menu = MachineMenu(machines: [older, newer])

        #expect(menu.sections.first?.machines.map(\.name) == ["Hammer Strength", "Plate loaded"])
    }

    @Test("Archived gyms keep one section at the very end")
    func archivedGymsCloseTheMenu() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let open = fixture.gym("Fitness X")
        let archivedOne = fixture.gym("Holiday Gym", isArchived: true)
        let archivedTwo = fixture.gym("Old Barn", isArchived: true)
        let here = fixture.machine(for: exercise, at: open, label: "Green")
        let there = fixture.machine(for: exercise, at: archivedOne, label: "Blue")
        let elsewhere = fixture.machine(for: exercise, at: archivedTwo, label: "Rusty")

        let menu = MachineMenu(machines: [there, here, elsewhere])

        #expect(menu.sections.map(\.title) == ["Fitness X", "Archived"])
        #expect(menu.sections.last?.machines.count == 2)
        #expect(menu.sections.last?.isArchived == true)
    }

    @Test("A machine whose gym was deleted is still reachable")
    func gymlessMachinesAreStillReachable() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let orphan = fixture.machine(for: exercise, at: nil, label: "Blue")

        let menu = MachineMenu(machines: [orphan])

        #expect(menu.sections.map(\.title) == ["No gym"])
        // It renders as its label with no gym suffix (SPEC §3, invariant 3).
        #expect(orphan.caption == "Blue")
    }

    @Test("Rows read label · gym, and an unnamed machine is Unlabelled")
    func rowsReadLabelAndGym() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let made = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        let unnamed = fixture.machine(for: exercise, at: gym)
        let labelled = fixture.machine(for: exercise, at: gym, manufacturer: "Technogym", label: "By the window")

        #expect(made.caption == "Hammer Strength · Fitness X")
        #expect(unnamed.caption == "Unlabelled · Fitness X")
        // A label of your own beats the make: it is what you call the thing.
        #expect(labelled.caption == "By the window · Fitness X")
    }
}
