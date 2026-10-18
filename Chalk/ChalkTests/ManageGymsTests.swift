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

    @Test("The goal rides along untouched — Move never pools two machines")
    func aMoveLeavesTheGoalAlone() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let wrong = fixture.gym("Fitness X")
        let right = fixture.gym("Old Barn")
        let machine = fixture.machine(for: exercise, at: wrong, label: "Green")
        fixture.log(machine, reps: 5, weight: 100)
        let setAt = Date.days(ago: 3)
        GoalScope.machine(machine).set(reps: 5, weight: 140, at: setAt)

        fixture.gymsModel().move(machine, to: right)

        let reopened = try fixture.afterRelaunch()
        let reloaded = try #require(try reopened.fetch(FetchDescriptor<Machine>()).first)
        #expect(reloaded.gym?.name == "Old Barn")
        #expect(reloaded.goalReps == 5)
        #expect(reloaded.goalWeight == 140)
        #expect(reloaded.goalSetAt == setAt)
    }

    @Test("Moving an erg machine repoints it, and its intervals follow with their incline")
    func movingAnErgMachineTakesItsIntervals() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let wrong = fixture.gym("FitX")
        let right = fixture.gym("Urban Gym")
        let machine = fixture.machine(for: treadmill, at: wrong, label: "Technogym Excite")
        fixture.interval(treadmill, machine: machine, incline: 1.5, on: .days(ago: 2))
        fixture.interval(treadmill, machine: machine, incline: 3, on: .days(ago: 1))

        fixture.gymsModel().move(machine, to: right)

        let reopened = try fixture.afterRelaunch()
        let reloaded = try #require(try reopened.fetch(FetchDescriptor<Machine>()).first)
        #expect(reloaded.caption == "Technogym Excite · Urban Gym")
        #expect(reloaded.entries?.compactMap(\.incline).sorted() == [1.5, 3])
        // A gym's recency counts valid intervals (SPEC §13.12), so it moves too.
        #expect(right.lastLogged != nil)
        #expect(wrong.lastLogged == nil)
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

    // MARK: - Rename… on a machine (SPEC §7.5, §13.11)

    @Test("Renaming a machine is cosmetic, in either half: its entries and goal stay put")
    func renamingAMachineIsCosmetic() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let treadmill = fixture.erg("Treadmill")
        let gym = fixture.gym("FitX")
        let green = fixture.machine(for: legPress, at: gym, label: "Green")
        let excite = fixture.machine(for: treadmill, at: gym)
        fixture.log(green, reps: 5, weight: 100)
        fixture.interval(treadmill, machine: excite, incline: 1)
        let setAt = Date.days(ago: 2)
        GoalScope.machine(green).set(reps: 5, weight: 140, at: setAt)
        let model = fixture.gymsModel()

        model.rename(green, to: "  Hammer Strength ")
        model.rename(excite, to: "Technogym Excite")

        let reopened = try fixture.afterRelaunch()
        let machines = try reopened.fetch(FetchDescriptor<Machine>())
        let lift = try #require(machines.first { $0.id == green.id })
        let erg = try #require(machines.first { $0.id == excite.id })
        #expect(lift.name == "Hammer Strength")
        #expect(lift.entries?.count == 1)
        #expect(lift.goalSetAt == setAt)
        #expect(erg.name == "Technogym Excite")
        #expect(erg.entries?.first?.incline == 1)
    }

    @Test("A blank machine name leaves the label unchanged")
    func aBlankMachineNameChangesNothing() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("FitX")
        let excite = fixture.machine(for: treadmill, at: gym, label: "Technogym Excite")
        let unlabelled = fixture.machine(for: legPress, at: gym)
        let model = fixture.gymsModel()

        model.rename(excite, to: "   ")
        model.rename(unlabelled, to: "")

        #expect(excite.label == "Technogym Excite")
        #expect(unlabelled.label == nil)
        #expect(unlabelled.name == "Unlabelled")
    }

    // MARK: - A gym's machines, in both halves (SPEC §13.11)

    @Test("A gym's machines sit in Strength and Endurance sections, each most recently used first")
    func aGymsMachinesSitInTwoSections() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let treadmill = fixture.erg("Treadmill")
        let rower = fixture.erg("Rower", unit: .split)
        let gym = fixture.gym("FitX")
        let green = fixture.machine(for: legPress, at: gym, label: "Green")
        let hammer = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        let excite = fixture.machine(for: treadmill, at: gym, label: "Technogym Excite")
        let concept = fixture.machine(for: rower, at: gym, label: "Concept2")
        fixture.log(green, reps: 5, weight: 100, on: .days(ago: 9))
        fixture.log(hammer, reps: 5, weight: 100, on: .days(ago: 2))
        fixture.interval(treadmill, machine: excite, on: .days(ago: 7))
        fixture.interval(rower, machine: concept, intensity: 105, on: .days(ago: 1))

        let list = GymMachinesList(gym: gym)

        #expect(list.strength.map(\.name) == ["Hammer Strength", "Green"])
        #expect(list.endurance.map(\.name) == ["Concept2", "Technogym Excite"])
    }

    @Test("An empty section is hidden, and the screen is never filtered by the half you came from")
    func anEmptySectionIsHidden() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let ergsOnly = fixture.gym("FitX")
        let liftsOnly = fixture.gym("Old Barn")
        let both = fixture.gym("Urban Gym")
        fixture.machine(for: treadmill, at: ergsOnly, label: "Technogym Excite")
        fixture.machine(for: legPress, at: liftsOnly, label: "Green")
        fixture.machine(for: treadmill, at: both, label: "Matrix T7")
        fixture.machine(for: legPress, at: both, label: "Cybex")

        #expect(GymMachinesList(gym: ergsOnly).sections == [.endurance])
        #expect(GymMachinesList(gym: liftsOnly).sections == [.strength])
        // There is no half to filter by: the screen takes a gym and nothing else.
        #expect(GymMachinesList(gym: both).sections == [.strength, .endurance])
        #expect(GymMachinesList(gym: fixture.gym("Typo Gym")).sections.isEmpty)
    }

    @Test("A gym's machine count covers both halves, so an erg machine alone blocks the hard delete")
    func anErgMachineBlocksTheHardDelete() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("FitX")
        fixture.machine(for: treadmill, at: gym, label: "Technogym Excite")
        fixture.machine(for: legPress, at: gym, label: "Green")
        let ergOnly = fixture.gym("Old Barn")
        fixture.machine(for: treadmill, at: ergOnly)
        let model = fixture.gymsModel()

        #expect(GymMachinesList(gym: gym).count == 2)
        #expect(model.canDelete(ergOnly) == false)
        model.delete(ergOnly)
        #expect(model.allGyms.contains { $0 === ergOnly })
    }
}
