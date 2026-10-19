import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The lap-list sheet on a gym-bound erg's machine (SPEC §13.7, §6.4).
///
/// **One caption covers every row**: a block is logged on one machine, so the machine is
/// the sheet's, not a row's. What an implementer gets wrong: **the archived gym comes
/// back once per Save**, not once per row — and, as in strength, **picking an archived
/// gym's machine is not yet standing in it**; the Save is.
@Suite("Lap-list machine")
struct LapListMachineTests {

    // MARK: - The caption

    @Test("A transferable erg's sheet carries no machine caption at all")
    func aTransferableErgHasNoCaption() throws {
        let fixture = try LibraryFixture()
        let skiErg = fixture.erg("SkiErg", unit: .split, kind: .freeWeight)

        let model = fixture.lapListModel(for: skiErg)

        #expect(model.machineCaption == nil)
        #expect(model.machineMenu.isEmpty)
    }

    @Test("The caption reads label · gym once, above every row")
    func theCaptionReadsLabelAndGym() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let machine = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")

        let model = fixture.lapListModel(for: treadmill, on: machine)
        model.addRow()

        #expect(model.machineCaption == "Technogym Run · Urban Gym")
    }

    @Test("A gym-bound erg with no machine yet says so and cannot save")
    func aGymBoundErgWithNoMachineCannotSave() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")

        let model = fixture.lapListModel(for: treadmill)
        model.fill(0, "600", "15.0", "0", "156", "164")

        #expect(model.machineCaption == "No machine")
        // Every row is complete and valid — the machine is all that is missing, and an
        // entry with none is not producible on a gym-bound erg (SPEC §3, invariant 4).
        #expect(model.drawn == ["6:00 | 15.0 | 0 | 156 | 164"])
        #expect(model.canSave == false)
        model.save()
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).isEmpty)
    }

    // MARK: - Saving

    @Test("Saving on a machine writes every row onto it")
    func savingWritesEveryRowOntoTheMachine() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let machine = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        try fixture.save()

        let model = fixture.lapListModel(for: treadmill, on: machine)
        model.fill(0, "600", "15.0", "0", "156", "164")
        model.addRow()
        model.addRow()
        #expect(model.saveTitle == "Save 3")
        model.save()

        let entries = try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>())
        #expect(entries.count == 3)
        #expect(entries.allSatisfy { $0.machine?.id == machine.id && $0.exercise?.id == treadmill.id })
    }

    @Test("New machine here resolves the sheet to it, and the block lands on it")
    func newMachineHereResolvesTheSheet() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .split)
        let gym = fixture.gym("Urban Gym")
        try fixture.save()

        let gyms = fixture.gymsModel()
        let model = fixture.lapListModel(for: rower, gyms: gyms)
        model.fill(0, "400", "105.0", "150", "158")
        #expect(model.canSave == false)

        model.createMachine(at: gym, named: "Concept2")

        #expect(model.machineCaption == "Concept2 · Urban Gym")
        #expect(model.canSave)
        model.save()
        let machine = try #require(rower.machines?.first)
        #expect(machine.label == "Concept2")
        #expect(machine.entries?.count == 1)
        // Making a machine while logging is standing in that gym (SPEC §6.4).
        #expect(gyms.currentGym === gym)
    }

    // MARK: - Seeding

    @Test("The first row seeds from this machine's most recent valid interval, never a sibling's")
    func theFirstRowSeedsFromThisMachine() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let here = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        let there = fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Matrix T7")
        fixture.interval(treadmill, machine: here, duration: 360, intensity: 15.0, incline: 1, average: 164, peak: 170, on: .days(ago: 5))
        // Newer, but on another machine — its speed means something else (SPEC §13.7).
        fixture.interval(treadmill, machine: there, duration: 300, intensity: 13.5, incline: 0, average: 150, peak: 158, on: .days(ago: 1))

        let model = fixture.lapListModel(for: treadmill, on: here)

        #expect(model.drawn == ["6:00 | 15.0 | 1 | 164 | 170"])
    }

    @Test("Picking another machine on an untouched sheet re-seeds from it")
    func pickingAnotherMachineReseedsAnUntouchedSheet() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let here = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        let there = fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Matrix T7")
        fixture.interval(treadmill, machine: here, duration: 360, intensity: 15.0, incline: 1, average: 164, peak: 170, on: .days(ago: 5))
        fixture.interval(treadmill, machine: there, duration: 300, intensity: 13.5, incline: 0, average: 150, peak: 158, on: .days(ago: 1))
        try fixture.save()

        let model = fixture.lapListModel(for: treadmill, on: here)
        model.select(there)

        #expect(model.machineCaption == "Matrix T7 · FitX")
        #expect(model.drawn == ["5:00 | 13.5 | 0 | 150 | 158"])
    }

    @Test("Picking another machine keeps a block already typed")
    func pickingAnotherMachineKeepsTypedRows() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let here = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        let there = fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Matrix T7")
        fixture.interval(treadmill, machine: there, duration: 300, intensity: 13.5, incline: 0, average: 150, peak: 158, on: .days(ago: 1))
        try fixture.save()

        let model = fixture.lapListModel(for: treadmill, on: here)
        model.fill(0, "600", "15.0", "1", "156", "164")
        model.addRow()
        model.select(there)

        // The block is what you did; the caption only corrects where you did it.
        #expect(model.drawn == ["6:00 | 15.0 | 1 | 156 | 164", "6:00 | 15.0 | 1 | 156 | 164"])
    }

    @Test("A machine belonging to another erg is refused")
    func aMachineOfAnotherErgIsRefused() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let rower = fixture.erg("Rower", unit: .split)
        let gym = fixture.gym("Urban Gym")
        let mine = fixture.machine(for: treadmill, at: gym, label: "Technogym Run")
        let theirs = fixture.machine(for: rower, at: gym, label: "Concept2")
        try fixture.save()

        let model = fixture.lapListModel(for: treadmill, on: mine)
        model.select(theirs)

        #expect(model.machineCaption == "Technogym Run · Urban Gym")
    }

    // MARK: - The current gym

    @Test("Picking another gym's machine moves the current gym at the pick")
    func pickingAnotherGymsMachineMovesTheCurrentGym() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let home = fixture.gym("Urban Gym")
        let away = fixture.gym("FitX")
        let atHome = fixture.machine(for: treadmill, at: home, label: "Technogym Run")
        let atAway = fixture.machine(for: treadmill, at: away, label: "Matrix T7")
        try fixture.save()

        let gyms = fixture.gymsModel()
        gyms.select(home)
        let model = fixture.lapListModel(for: treadmill, on: atHome, gyms: gyms)

        model.select(atAway)

        // At the pick, not at the Save — as strength's caption (SPEC §6.4).
        #expect(gyms.currentGym === away)
    }

    @Test("Saving on an archived gym's machine un-archives it and makes it current, once per Save")
    func savingOnAnArchivedGymUnarchivesItOnce() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let home = fixture.gym("Urban Gym")
        let old = fixture.gym("Old Barn", isArchived: true)
        let atHome = fixture.machine(for: treadmill, at: home, label: "Technogym Run")
        let atOld = fixture.machine(for: treadmill, at: old, label: "Rusty")
        try fixture.save()

        let gyms = fixture.gymsModel()
        gyms.select(home)
        let model = fixture.lapListModel(for: treadmill, on: atHome, gyms: gyms)

        model.select(atOld)
        // Tapping an archived gym's row is not yet standing in it (SPEC §7.4).
        #expect(gyms.currentGym === home)
        #expect(old.isArchived)

        model.fill(0, "600", "15.0", "0", "156", "164")
        model.addRow()
        model.addRow()
        model.save()

        // The Save is what says otherwise — one visit, however many rows it wrote.
        #expect(old.isArchived == false)
        #expect(gyms.currentGym === old)
        #expect(gyms.gyms.map(\.name) == ["Old Barn", "Urban Gym"])
        let reopened = try fixture.afterRelaunch().fetch(FetchDescriptor<Gym>())
        #expect(reopened.first { $0.name == "Old Barn" }?.isArchived == false)
    }

    // MARK: - The menu

    @Test("The gym you are standing in gets a section even with no machine for this erg")
    func theCurrentGymAlwaysGetsASection() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let known = fixture.gym("Urban Gym")
        let standingIn = fixture.gym("FitX")
        fixture.gym("Old Barn")
        let machine = fixture.machine(for: treadmill, at: known, label: "Technogym Run")
        try fixture.save()

        let gyms = fixture.gymsModel()
        gyms.select(standingIn)
        let model = fixture.lapListModel(for: treadmill, on: machine, gyms: gyms)

        #expect(model.machineMenu.sections.map(\.title) == ["FitX", "Urban Gym"])
    }

    @Test("A gym made from New gym… gets a section to make its machine in")
    func aNewGymGetsASection() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let gyms = fixture.gymsModel()
        let model = fixture.lapListModel(for: treadmill, gyms: gyms)
        #expect(model.machineMenu.isEmpty)

        let gym = try #require(gyms.create(named: "Urban Gym"))
        model.gymCreated(gym)

        #expect(model.machineMenu.sections.map(\.title) == ["Urban Gym"])
    }
}

// MARK: - Helpers

extension LapListModel {
    /// Types one row, a cell at a time, left to right.
    func fill(_ row: Int, _ cells: String...) {
        for (field, keys) in zip(columns, cells) {
            select(Cell(row: row, field: field))
            type(keys)
        }
    }
}
