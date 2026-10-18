import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The erg detail screen's lifetime operations (SPEC §13.6, §13.8) — for now the bare
/// screen: its name, the empty state, and an overflow of Rename, *Change unit…* and
/// Delete.
///
/// The rule an implementer gets subtly wrong: **the unit is locked by any entry**, not by
/// the first valid interval — once a number is logged in a unit, changing the unit would
/// reinterpret it, and there is no repair. *Change unit…* is absent, not disabled, and the
/// model refuses the change on its own as well.
@Suite("Erg detail model")
struct ErgDetailModelTests {

    // MARK: - Change unit

    @Test("With no entries, the unit can be changed, and the change survives relaunch")
    func theUnitChangesWithNoEntries() throws {
        let fixture = try LibraryFixture()
        let erg = fixture.erg("Bike Erg", unit: .level)
        try fixture.save()
        let model = fixture.ergDetailModel(for: erg)
        #expect(model.canChangeUnit)

        #expect(model.changeUnit(to: .watts))

        #expect(model.unit == .watts)
        let relaunched = try fixture.afterRelaunch().fetch(FetchDescriptor<Exercise>())
        #expect(relaunched.map(\.unit) == ["watts"])
    }

    @Test("Once the erg has an entry, the unit is locked")
    func oneEntryLocksTheUnit() throws {
        let fixture = try LibraryFixture()
        let erg = fixture.erg("Treadmill", unit: .speed, kind: .freeWeight)
        fixture.interval(erg, duration: 360, intensity: 15.0, average: 164)
        try fixture.save()
        let model = fixture.ergDetailModel(for: erg)

        #expect(!model.canChangeUnit)
        #expect(!model.changeUnit(to: .watts))
        #expect(model.unit == .speed)
        #expect(erg.ergUnit == .speed)
    }

    @Test("An entry on one of a gym-bound erg's machines locks the unit too")
    func aMachinesEntryLocksTheUnit() throws {
        let fixture = try LibraryFixture()
        let erg = fixture.erg("Treadmill", unit: .speed)
        let machine = fixture.machine(for: erg, at: fixture.gym("Fitness X"))
        fixture.interval(erg, machine: machine)
        try fixture.save()

        #expect(!fixture.ergDetailModel(for: erg).canChangeUnit)
    }

    @Test("Changing the unit clears the erg's goal, and every machine's")
    func changingTheUnitClearsTheGoal() throws {
        let fixture = try LibraryFixture()
        let erg = fixture.erg("Bike Erg", unit: .watts, kind: .freeWeight)
        erg.goalZone = 3
        erg.goalDuration = 600
        erg.goalIntensity = 260
        erg.goalSetAt = .days(ago: 2)
        let other = fixture.erg("Air Bike", unit: .watts)
        let machine = fixture.machine(for: other, at: fixture.gym("Fitness X"))
        machine.goalZone = 4
        machine.goalDuration = 360
        machine.goalIntensity = 300
        machine.goalSetAt = .days(ago: 1)
        try fixture.save()

        fixture.ergDetailModel(for: erg).changeUnit(to: .level)
        fixture.ergDetailModel(for: other).changeUnit(to: .level)

        #expect(erg.goalZone == nil && erg.goalDuration == nil && erg.goalIntensity == nil)
        #expect(erg.goalSetAt == nil)
        #expect(machine.goalZone == nil && machine.goalDuration == nil && machine.goalIntensity == nil)
        #expect(machine.goalSetAt == nil)
    }

    // MARK: - Rename and delete

    @Test("Renaming an erg retitles its tile on the grid behind it")
    func renamingRetitlesTheTile() throws {
        let fixture = try LibraryFixture()
        let erg = fixture.erg("Treadmill")
        try fixture.save()
        let library = fixture.libraryModel()
        library.show(.endurance)

        let model = library.ergDetail(for: erg)
        model.rename(to: "  Technogym Run ")

        #expect(model.name == "Technogym Run")
        #expect(library.content.drawn == "grid Ungrouped[Technogym Run]")
    }

    @Test("Deleting an erg asks with its entry count and empties the grid behind it")
    func deletingAnErgEmptiesTheGrid() throws {
        let fixture = try LibraryFixture()
        let erg = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(erg, on: .days(ago: 2))
        fixture.interval(erg, on: .days(ago: 1))
        try fixture.save()
        let library = fixture.libraryModel()
        library.show(.endurance)
        let model = library.ergDetail(for: erg)

        #expect(model.deleteConfirmation == "Delete Treadmill and its 2 entries?")
        model.delete()

        #expect(library.content.drawn == "empty")
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).isEmpty)
    }

    @Test("An erg with nothing logged is not asked about entries")
    func anUnloggedErgIsAskedPlainly() throws {
        let fixture = try LibraryFixture()
        let erg = fixture.erg("SkiErg", unit: .split)
        try fixture.save()

        #expect(fixture.ergDetailModel(for: erg).deleteConfirmation == "Delete SkiErg?")
    }
}
