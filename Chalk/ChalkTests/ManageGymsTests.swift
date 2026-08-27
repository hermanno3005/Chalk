import Foundation
import SwiftData
import Testing

@testable import Chalk

/// `Manage gyms…` — the one gym admin surface (SPEC §7.4, #31). Four verbs on a gym
/// (rename, archive, delete, tap through) and one on a machine (`Move to another gym…`).
///
/// The line every one of them is measured against: **archive hides, never destroys**, and
/// the only thing that leaves the store is a gym with nothing to lose.
@Suite("Manage gyms")
struct ManageGymsTests {

    // MARK: - Rename

    @Test("Renaming is cosmetic: machines, entries and the current gym all survive it")
    func renamingCostsNothing() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitnes X")
        let machine = fixture.machine(for: exercise, at: gym, label: "Green")
        fixture.log(machine, reps: 5, weight: 100)
        let model = fixture.gymsModel()
        model.select(gym)

        model.rename(gym, to: "  Fitness X  ")

        #expect(gym.name == "Fitness X")
        #expect(gym.machines?.count == 1)
        #expect(machine.entries?.count == 1)
        // Identity is `Gym.id`, and the setting holds that UUID rather than the name.
        #expect(model.currentGym === gym)
        #expect(fixture.defaults.string(forKey: GymsModel.currentGymKey) == gym.id.uuidString)
    }

    @Test("A blank name is not a rename")
    func aBlankNameLeavesTheGymAlone() throws {
        let fixture = try LibraryFixture()
        let gym = fixture.gym("Fitness X")
        let model = fixture.gymsModel()

        model.rename(gym, to: "   ")

        #expect(gym.name == "Fitness X")
    }

    // MARK: - Archive

    @Test("Archiving takes the gym out of the picker and changes no curve")
    func archivingHidesAndNothingMore() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Holiday Gym")
        let machine = fixture.machine(for: exercise, at: gym, label: "Green")
        fixture.log(machine, reps: 5, weight: 100)
        let model = fixture.gymsModel()

        model.archive(gym)

        #expect(model.gyms.isEmpty)
        #expect(model.allGyms.map(\.name) == ["Holiday Gym"])
        // The derivation never sees `isArchived` (SPEC §7.4).
        #expect(machine.entries?.count == 1)
        #expect(RepMaxCurve.best(atLeast: 5, in: try #require(machine.entries)) == 100)
        #expect(fixture.detailModel(for: exercise).readout?.weight == 100)
    }

    @Test("Archiving the gym you are standing in clears the current-gym setting")
    func archivingTheCurrentGymClearsTheSetting() throws {
        let fixture = try LibraryFixture()
        let gym = fixture.gym("Holiday Gym")
        let model = fixture.gymsModel()
        model.select(gym)

        model.archive(gym)

        #expect(model.currentGym == nil)
        // Cleared rather than left pointed at something hidden — so a relaunch does not
        // resolve it back either.
        #expect(fixture.defaults.string(forKey: GymsModel.currentGymKey) == nil)
        #expect(fixture.gymsModel().currentGym == nil)
    }

    @Test("Archiving another gym leaves where you are standing alone")
    func archivingElsewhereLeavesTheCurrentGym() throws {
        let fixture = try LibraryFixture()
        let here = fixture.gym("Fitness X")
        let there = fixture.gym("Holiday Gym")
        let model = fixture.gymsModel()
        model.select(here)

        model.archive(there)

        #expect(model.currentGym === here)
    }

    // MARK: - Delete

    @Test("Delete is offered only for a gym with no machines")
    func onlyAnEmptyGymCanBeDeleted() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let empty = fixture.gym("Typo Gym")
        let used = fixture.gym("Fitness X")
        fixture.machine(for: exercise, at: used, label: "Green")
        let model = fixture.gymsModel()

        #expect(model.canDelete(empty))
        #expect(model.canDelete(used) == false)
    }

    @Test("Deleting an empty gym removes it for good")
    func deletingAnEmptyGymRemovesIt() throws {
        let fixture = try LibraryFixture()
        let gym = fixture.gym("Typo Gym")
        let model = fixture.gymsModel()
        model.select(gym)

        model.delete(gym)

        #expect(model.allGyms.isEmpty)
        #expect(model.currentGym == nil)
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Gym>()).isEmpty)
    }

    @Test("A gym holding machines cannot be deleted — “delete” and “lose history” never share a tap")
    func deletingAGymWithMachinesDoesNothing() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let machine = fixture.machine(for: exercise, at: gym, label: "Green")
        fixture.log(machine, reps: 5, weight: 100)
        let model = fixture.gymsModel()

        model.delete(gym)

        #expect(model.allGyms.map(\.name) == ["Fitness X"])
        #expect(machine.gym === gym)
        #expect(machine.entries?.count == 1)
    }

    // MARK: - Move to another gym…

    @Test("Moving a machine repoints it, and its entries follow")
    func movingAMachineTakesItsEntriesWithIt() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let wrong = fixture.gym("Fitness X")
        let right = fixture.gym("Old Barn")
        let machine = fixture.machine(for: exercise, at: wrong, label: "Green")
        fixture.log(machine, reps: 5, weight: 100, on: .days(ago: 1))
        let model = fixture.gymsModel()

        model.move(machine, to: right)

        #expect(machine.gym === right)
        #expect(machine.caption == "Green · Old Barn")
        #expect(right.machines?.count == 1)
        #expect(wrong.machines?.isEmpty == true)
        // Entries hang off the machine, so the history — and the recency the gym is
        // ordered by — goes with it rather than staying behind.
        #expect(machine.entries?.count == 1)
        #expect(right.lastLogged != nil)
        #expect(wrong.lastLogged == nil)
        // And the husk is now the empty gym the delete verb is for.
        #expect(model.canDelete(wrong))
    }

    @Test("A move survives a relaunch")
    func aMoveIsWrittenToTheStore() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let wrong = fixture.gym("Fitness X")
        let right = fixture.gym("Old Barn")
        let machine = fixture.machine(for: exercise, at: wrong, label: "Green")
        fixture.log(machine, reps: 5, weight: 100)

        fixture.gymsModel().move(machine, to: right)

        let reopened = try fixture.afterRelaunch()
        let reloaded = try #require(try reopened.fetch(FetchDescriptor<Machine>()).first)
        #expect(reloaded.gym?.name == "Old Barn")
        #expect(reloaded.entries?.count == 1)
    }

    @Test("Move targets are every other gym, the ones you use first and archived after")
    func moveTargetsAreEveryOtherGym() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let here = fixture.gym("Fitness X")
        let old = fixture.gym("Old Barn")
        let husk = fixture.gym("Holiday Gym", isArchived: true)
        fixture.log(fixture.machine(for: exercise, at: old), reps: 5, weight: 60, on: .days(ago: 30))
        fixture.log(fixture.machine(for: exercise, at: here), reps: 5, weight: 60, on: .days(ago: 1))
        let model = fixture.gymsModel()

        // Never the gym the machine is already at — and an archived one is still a
        // target, because moving a machine back out of the wrong husk is the repair.
        #expect(model.moveTargets(excluding: here).map(\.name) == ["Old Barn", "Holiday Gym"])
    }

    @Test("The only gym you own is nowhere to move to, so the verb has no targets")
    func aSingleGymOffersNoMoveTargets() throws {
        let fixture = try LibraryFixture()
        let gym = fixture.gym("Fitness X")

        #expect(fixture.gymsModel().moveTargets(excluding: gym).isEmpty)
    }

    // MARK: - The sheet's two sections

    @Test("Gyms list in recency order, with archived ones in a section at the bottom")
    func theListSectionsArchivedGymsLast() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let old = fixture.gym("Old Barn")
        let recent = fixture.gym("Fitness X")
        let archived = fixture.gym("Holiday Gym", isArchived: true)
        fixture.log(fixture.machine(for: exercise, at: old), reps: 5, weight: 60, on: .days(ago: 30))
        fixture.log(fixture.machine(for: exercise, at: recent), reps: 5, weight: 60, on: .days(ago: 1))
        fixture.log(fixture.machine(for: exercise, at: archived), reps: 5, weight: 60, on: .days(ago: 0))

        let list = ManageGymsList(gyms: fixture.gymsModel().allGyms)

        #expect(list.inUse.map(\.name) == ["Fitness X", "Old Barn"])
        #expect(list.archived.map(\.name) == ["Holiday Gym"])
    }

    @Test("The admin sheet pins nothing: it is a list of gyms, not a picker")
    func theListDoesNotPinTheCurrentGym() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let old = fixture.gym("Old Barn")
        let recent = fixture.gym("Fitness X")
        fixture.log(fixture.machine(for: exercise, at: old), reps: 5, weight: 60, on: .days(ago: 30))
        fixture.log(fixture.machine(for: exercise, at: recent), reps: 5, weight: 60, on: .days(ago: 1))
        let model = fixture.gymsModel()
        model.select(old)

        #expect(ManageGymsList(gyms: model.allGyms).inUse.map(\.name) == ["Fitness X", "Old Barn"])
    }
}
