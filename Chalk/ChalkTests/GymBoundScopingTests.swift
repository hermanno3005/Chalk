import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The app's second shape, end to end: a gym-bound exercise scoped to one machine
/// (SPEC §5.3, §6.4, §7.3), and the two invariants app code has to hold — an entry's
/// machine belongs to its exercise, and a gym-bound entry always has one (§3).
@Suite("Gym-bound scoping")
struct GymBoundScopingTests {

    // MARK: - The detail screen's shape

    @Test("A free-weight exercise has no qualifier at all")
    func freeWeightExercisesHaveNoQualifier() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Squat")
        fixture.log(exercise, reps: 5, weight: 100)

        let model = fixture.detailModel(for: exercise)

        #expect(model.isGymBound == false)
        #expect(model.machine == nil)
        #expect(model.machines.isEmpty)
        #expect(model.machineMenu.isEmpty)
        #expect(model.needsFirstMachine == false)
    }

    @Test("A gym-bound curve counts only the scoped machine's entries")
    func aGymBoundCurveCountsOneMachine() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let there = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(here, reps: 5, weight: 100)
        fixture.log(there, reps: 5, weight: 200)

        let gyms = fixture.gymsModel()
        gyms.select(gym)
        let model = fixture.detailModel(for: exercise, gyms: gyms)
        // Two at the current gym: the most recently logged wins, and these were logged
        // in order.
        #expect(model.machine === there)
        #expect(model.readout?.weight == 200)
        #expect(model.readout?.entriesBehind == 1)

        model.select(here)

        #expect(model.readout?.weight == 100)
        #expect(model.readout?.entriesBehind == 1)
    }

    @Test("Switching machines re-derives the whole curve, ghost included")
    func switchingMachinesReDerivesTheCurve() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let proven = fixture.machine(for: exercise, at: gym, label: "Old")
        let untouched = fixture.machine(for: exercise, at: gym, label: "New")
        fixture.log(proven, reps: 5, weight: 100)

        let model = fixture.detailModel(for: exercise)
        #expect(model.machine === proven)
        #expect(model.hasCurve)

        model.select(untouched)

        // A machine you have never logged on draws no chart at all (SPEC §5.4).
        #expect(model.hasCurve == false)
        #expect(model.readout == nil)
        #expect(model.curve.ghost.isEmpty)
    }

    @Test("The screen stays on the machine you switched to when it re-reads")
    func theScopedMachineIsSticky() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let current = fixture.gym("Fitness X")
        let elsewhere = fixture.gym("Old Barn")
        let atCurrent = fixture.machine(for: exercise, at: current, label: "Green")
        let atOther = fixture.machine(for: exercise, at: elsewhere, label: "Blue")

        let gyms = fixture.gymsModel()
        gyms.select(current)
        let model = fixture.detailModel(for: exercise, gyms: gyms)
        #expect(model.machine === atCurrent)

        model.select(atOther)
        // What a log, an edit or a delete does behind the screen.
        model.refresh()

        #expect(model.machine === atOther)
    }

    @Test("An exercise with no machines is in its empty state, and logging makes one")
    func aGymBoundExerciseWithNoMachinesLogsItsFirst() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)

        let model = fixture.detailModel(for: exercise)

        #expect(model.isGymBound)
        #expect(model.machine == nil)
        #expect(model.hasCurve == false)
        #expect(model.needsFirstMachine)
        // The Log bar still opens: `New machine here` inside the sheet's own picker is
        // the one hole no caller can close (SPEC §6.4). What holds is the invariant —
        // `Entry.machine == nil` on a gym-bound exercise is not producible (§3), and the
        // sheet refuses to save without one.
        #expect(model.logSheet {}.canSave == false)
    }

    @Test("The first machine created for an exercise resolves on the next read")
    func theFirstMachineResolvesOnTheNextRead() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let model = fixture.detailModel(for: exercise)
        #expect(model.needsFirstMachine)

        let machine = fixture.machine(for: exercise, at: gym, label: "Green")
        model.refresh()

        #expect(model.machine === machine)
        #expect(model.needsFirstMachine == false)
    }

    // MARK: - What the sheets are handed

    @Test("Logging from the detail screen writes the entry onto the scoped machine")
    func loggingWritesTheEntryOntoTheScopedMachine() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let machine = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")

        let model = fixture.detailModel(for: exercise)
        let sheet = model.logSheet {}
        sheet.advance()
        sheet.type(.digit(6))
        sheet.type(.digit(0))
        sheet.save()

        #expect(model.readout?.weight == 60)
        let logged = try #require(machine.entries?.first)
        // Both invariants at once: the entry has a machine, and the machine is this
        // exercise's (SPEC §3, invariants 1 and 4).
        #expect(logged.machine === machine)
        #expect(logged.machine?.exercise === logged.exercise)
    }

    @Test("The verdict and the seed read the scoped machine only")
    func theVerdictReadsTheScopedMachineOnly() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "Green")
        let elsewhere = fixture.machine(for: exercise, at: gym, label: "Blue")
        fixture.log(elsewhere, reps: 5, weight: 200, on: .days(ago: 1))

        let sheet = fixture.logSheetModel(for: exercise, on: here)
        sheet.advance()

        // Nothing proven *here*, so nothing is seeded and nothing is claimed. The
        // sibling's 200 kg is quoted as the hint it is (SPEC §6.5) and seeds nothing.
        #expect(sheet.reps == 5)
        #expect(sheet.weight == nil)
        #expect(sheet.verdict == .hint("No history here — \(200.0.kilogramsText) kg × 5 on Blue"))
    }

    @Test("A gym-bound sheet with no machine refuses to save")
    func aMachinelessGymBoundSheetRefusesToSave() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)

        let sheet = fixture.logSheetModel(for: exercise)
        sheet.advance()
        sheet.type(.digit(6))
        sheet.type(.digit(0))

        #expect(sheet.canSave == false)
        sheet.save()
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).isEmpty)
    }

    @Test("Editing an entry keeps it on its own machine")
    func editingAnEntryKeepsItsMachine() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let machine = fixture.machine(for: exercise, at: gym, label: "Green")
        fixture.log(machine, reps: 5, weight: 100)

        let history = fixture.historySheetModel(for: exercise, on: machine, atLeast: 5)
        let edit = history.editSheet(for: try #require(history.rows.first))
        edit.advance()
        edit.tapNumber()
        edit.type(.digit(9))
        edit.type(.digit(5))
        edit.save()

        #expect(machine.entries?.count == 1)
        #expect(machine.entries?.first?.weight == 95)
    }

    @Test("The history sheet lists the scoped machine's entries only")
    func theHistorySheetIsScopedToo() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "Green")
        let there = fixture.machine(for: exercise, at: gym, label: "Blue")
        fixture.log(here, reps: 5, weight: 100, on: .days(ago: 2))
        fixture.log(there, reps: 5, weight: 200, on: .days(ago: 1))

        let detail = fixture.detailModel(for: exercise)
        detail.select(here)
        let history = try #require(detail.historySheet())

        #expect(history.rows.count == 1)
        #expect(history.rows.first?.machine == "Green · Fitness X")
    }

    // MARK: - Creating one

    @Test("Creating a gym-bound exercise at a gym makes its first machine")
    func creatingAGymBoundExerciseMakesItsMachine() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let gym = try #require(model.gyms.create(named: "Fitness X"))

        let exercise = try #require(model.create(
            name: "Leg Press",
            kind: .gymBound,
            gym: gym,
            manufacturer: "  Hammer Strength  "
        ))

        let machine = try #require(exercise.machines?.first)
        #expect(machine.gym === gym)
        #expect(machine.caption == "Hammer Strength · Fitness X")
        #expect(fixture.detailModel(for: exercise).machine === machine)
    }

    @Test("A gym-bound exercise created with no gym has no machine yet")
    func creatingOneWithoutAGymMakesNoMachine() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()

        let exercise = try #require(model.create(name: "Leg Press", kind: .gymBound))

        #expect(exercise.machines?.isEmpty == true)
    }

    @Test("A free-weight exercise is never given a machine")
    func freeWeightExercisesNeverGetAMachine() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let gym = try #require(model.gyms.create(named: "Fitness X"))

        let exercise = try #require(model.create(
            name: "Squat",
            kind: .freeWeight,
            gym: gym,
            manufacturer: "Eleiko"
        ))

        #expect(exercise.machines?.isEmpty == true)
    }

    @Test("Log again resumes on the machine the entry was logged on")
    func logAgainResumesOnTheEntrysMachine() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let gym = try #require(model.gyms.create(named: "Fitness X"))
        let exercise = try #require(model.create(name: "Leg Press", kind: .gymBound, gym: gym))
        let machine = try #require(exercise.machines?.first)
        fixture.log(machine, reps: 8, weight: 55, on: .days(ago: 1))
        model.refresh()

        let sheet = model.logSheet(for: exercise)
        sheet.advance()
        sheet.save()

        #expect(machine.entries?.count == 2)
        #expect(machine.entries?.allSatisfy { $0.weight == 55 } == true)
    }
}

/// Archive is a **display** concept: the derivation never sees `isArchived` (SPEC §7.4).
/// The one write it takes is the visit itself — logging at an archived gym un-archives it,
/// which is why there is no `restore` verb anywhere in the app.
@Suite("Archived gyms")
struct ArchivedGymTests {

    @Test("Logging at an archived gym un-archives it")
    func loggingUnarchivesTheGym() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Holiday Gym", isArchived: true)
        let machine = fixture.machine(for: exercise, at: gym, label: "Green")

        let sheet = fixture.logSheetModel(for: exercise, on: machine)
        sheet.advance()
        sheet.type(.digit(6))
        sheet.type(.digit(0))
        sheet.save()

        #expect(gym.isArchived == false)
    }

    @Test("Correcting an old entry there is not a visit")
    func editingDoesNotUnarchiveTheGym() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Holiday Gym", isArchived: true)
        let machine = fixture.machine(for: exercise, at: gym, label: "Green")
        fixture.log(machine, reps: 5, weight: 100, on: .days(ago: 20))

        let history = fixture.historySheetModel(for: exercise, on: machine, atLeast: 5)
        let edit = history.editSheet(for: try #require(history.rows.first))
        edit.advance()
        edit.tapNumber()
        edit.type(.digit(9))
        edit.type(.digit(5))
        edit.save()

        #expect(machine.entries?.first?.weight == 95)
        #expect(gym.isArchived)
    }

    @Test("An archived gym's entries still derive")
    func archivedGymsStillDerive() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Holiday Gym", isArchived: true)
        let machine = fixture.machine(for: exercise, at: gym, label: "Green")
        fixture.log(machine, reps: 5, weight: 100)

        let model = fixture.detailModel(for: exercise)

        #expect(model.machine === machine)
        #expect(model.readout?.weight == 100)
    }
}
