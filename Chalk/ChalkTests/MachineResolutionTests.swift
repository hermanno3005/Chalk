import Foundation
import SwiftData
import Testing

@testable import Chalk

/// Machine resolution in the log sheet (SPEC §6.3, §6.4).
///
/// **The sheet never resolves a machine — its caller does.** It is handed one, it says so
/// in a caption on both stages, and the caption is how you correct it. What an
/// implementer gets wrong: **reps seed from any machine and the weight only from this
/// exact one**, and **stickiness splits by mode** — picking a machine at another gym
/// while logging moves the current gym, while editing it never does.
@Suite("Machine resolution")
struct MachineResolutionTests {

    // MARK: - The caption

    @Test("A free-weight sheet carries no machine row at all")
    func freeWeightSheetsHaveNoMachineRow() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Squat")
        fixture.log(exercise, reps: 5, weight: 100)

        let model = fixture.logSheetModel(for: exercise)

        // Not a disabled row and not a placeholder (SPEC §6.4).
        #expect(model.machineCaption == nil)
        #expect(model.machineMenu.isEmpty)
        model.advance()
        #expect(model.machineCaption == nil)
    }

    @Test("The caption reads label · gym on both stages")
    func theCaptionReadsOnBothStages() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let machine = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(machine, reps: 8, weight: 60)

        let model = fixture.logSheetModel(for: exercise, on: machine)

        #expect(model.machineCaption == "Hammer Strength · Fitness X")
        model.advance()
        // Both stages, because the entry mislabelled by a stale sticky gym is only
        // caught if the machine is on screen at commit time (SPEC §6.4).
        #expect(model.machineCaption == "Hammer Strength · Fitness X")
    }

    @Test("A gym-bound sheet with no machine yet says so and cannot save")
    func aSheetWithNoMachineSaysSo() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)

        let model = fixture.logSheetModel(for: exercise)
        model.advance()
        model.type(.digit(6))
        model.type(.digit(0))

        #expect(model.machineCaption == "No machine")
        // `Entry.machine == nil` on a gym-bound exercise is not producible (SPEC §3).
        #expect(model.canSave == false)
    }

    // MARK: - Seeding

    @Test("Reps seed from any machine, the weight only from this one")
    func repsSeedFromAnyMachineAndTheWeightFromThisOne() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let proven = fixture.machine(for: exercise, at: gym, label: "Green")
        let unproven = fixture.machine(for: exercise, at: gym, label: "Blue")
        fixture.log(proven, reps: 12, weight: 100, on: .days(ago: 2))

        let model = fixture.logSheetModel(for: exercise, on: unproven)

        // Rep counts transfer between machines in a way loads do not (SPEC §6.3).
        #expect(model.reps == 12)
        model.advance()
        // Never a weight from another machine: it would put a number you have never
        // lifted *there* one tap from Save.
        #expect(model.weight == nil)
        #expect(model.mode == .keypad)
    }

    @Test("A machine you have proven pre-fills its own weight")
    func aProvenMachinePreFillsItsOwnWeight() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "Green")
        let there = fixture.machine(for: exercise, at: gym, label: "Blue")
        fixture.log(here, reps: 8, weight: 60, on: .days(ago: 5))
        fixture.log(there, reps: 5, weight: 140, on: .days(ago: 1))

        let model = fixture.logSheetModel(for: exercise, on: here)

        #expect(model.reps == 5)
        model.advance()
        #expect(model.weight == 60)
        #expect(model.mode == .steppers)
    }

    @Test("A gym-bound repeat is still two taps: Next, Save")
    func aGymBoundRepeatIsStillTwoTaps() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let machine = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(machine, reps: 8, weight: 62.5, on: .days(ago: 2))
        try fixture.save()

        // The caller hands the sheet its machine, so resolution costs zero taps
        // (SPEC §6.4) and the two-tap log survives.
        let model = fixture.logSheetModel(for: exercise, on: machine)
        #expect(model.canAdvance)
        model.advance()
        #expect(model.canSave)
        model.save()

        let logged = try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>())
        #expect(logged.count == 2)
        #expect(logged.allSatisfy { $0.machine?.id == machine.id })
    }

    // MARK: - Correcting the machine

    @Test("Picking another machine re-seeds the weight and leaves the reps alone")
    func pickingAnotherMachineReSeedsTheWeight() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "Green")
        let there = fixture.machine(for: exercise, at: gym, label: "Blue")
        fixture.log(here, reps: 8, weight: 60, on: .days(ago: 5))
        fixture.log(there, reps: 5, weight: 140, on: .days(ago: 1))

        let model = fixture.logSheetModel(for: exercise, on: here)
        model.advance()
        #expect(model.weight == 60)

        model.select(there)

        #expect(model.machine === there)
        #expect(model.reps == 5)
        #expect(model.weight == 140)
        #expect(model.verdict == "Matches your 5-rep best")
    }

    @Test("Picking an unproven machine on the weight stage blanks it with the keypad up")
    func pickingAnUnprovenMachineBlanksTheWeight() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "Green")
        let fresh = fixture.machine(for: exercise, at: gym, label: "Blue")
        fixture.log(here, reps: 8, weight: 60, on: .days(ago: 5))

        let model = fixture.logSheetModel(for: exercise, on: here)
        model.advance()

        model.select(fresh)

        #expect(model.weight == nil)
        #expect(model.numberText == "")
        #expect(model.mode == .keypad)
        #expect(model.canSave == false)
    }

    @Test("A machine belonging to another exercise is refused")
    func aMachineFromAnotherExerciseIsRefused() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let other = fixture.exercise("Chest Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let mine = fixture.machine(for: exercise, at: gym, label: "Green")
        let theirs = fixture.machine(for: other, at: gym, label: "Blue")

        let model = fixture.logSheetModel(for: exercise, on: mine)
        model.select(theirs)

        // `entry.machine?.exercise == entry.exercise` (SPEC §3, invariant 1).
        #expect(model.machine === mine)
    }

    // MARK: - Stickiness, which splits by mode

    @Test("Confirming the machine you were handed still moves the current gym")
    func confirmingTheHandedMachineMovesTheCurrentGym() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let stale = fixture.gym("Fitness X")
        let here = fixture.gym("Holiday Gym")
        let machine = fixture.machine(for: exercise, at: here, label: "Blue")
        try fixture.save()

        let gyms = fixture.gymsModel()
        gyms.select(stale)
        // What the detail screen resolves to when the current gym holds no machine for
        // this exercise: the one most recently logged on overall (SPEC §5.3).
        let model = fixture.logSheetModel(for: exercise, on: machine, gyms: gyms)

        model.select(machine)

        // The mislabelled-by-stale-sticky-gym entry is the failure the caption exists
        // to catch (SPEC §6.4), so confirming it is a pick like any other.
        #expect(gyms.currentGym === here)
    }

    @Test("An archived gym becomes current on the log that un-archives it")
    func anArchivedGymBecomesCurrentOnTheLog() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let home = fixture.gym("Fitness X")
        let old = fixture.gym("Old Barn", isArchived: true)
        let atHome = fixture.machine(for: exercise, at: home, label: "Green")
        let atOld = fixture.machine(for: exercise, at: old, label: "Rusty")
        try fixture.save()

        let gyms = fixture.gymsModel()
        gyms.select(home)
        let model = fixture.logSheetModel(for: exercise, on: atHome, gyms: gyms)

        model.select(atOld)
        // Tapping an archived gym's row is not yet standing in it (SPEC §7.4) — and it
        // must not leave the app with no gym selected either.
        #expect(gyms.currentGym === home)

        model.advance()
        model.type(.digit(6))
        model.type(.digit(0))
        model.save()

        // The log is what says otherwise: it un-archives the gym, and the moment you
        // need one back is the moment you are standing in it.
        #expect(old.isArchived == false)
        #expect(gyms.currentGym === old)
    }

    @Test("Logging at another gym moves the current gym")
    func loggingAtAnotherGymMovesTheCurrentGym() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let home = fixture.gym("Fitness X")
        let away = fixture.gym("Holiday Gym")
        let atHome = fixture.machine(for: exercise, at: home, label: "Green")
        let atAway = fixture.machine(for: exercise, at: away, label: "Blue")
        try fixture.save()

        let gyms = fixture.gymsModel()
        gyms.select(home)
        let model = fixture.logSheetModel(for: exercise, on: atHome, gyms: gyms)

        model.select(atAway)

        // Silently — that is what makes "changeable in one tap" mean anything.
        #expect(gyms.currentGym === away)
    }

    @Test("Editing an old entry never moves the current gym")
    func editingNeverMovesTheCurrentGym() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let home = fixture.gym("Fitness X")
        let away = fixture.gym("Holiday Gym")
        let atHome = fixture.machine(for: exercise, at: home, label: "Green")
        let atAway = fixture.machine(for: exercise, at: away, label: "Blue")
        fixture.log(atHome, reps: 8, weight: 60, on: .days(ago: 21))
        try fixture.save()
        let entry = try #require(atHome.entries?.first)

        let gyms = fixture.gymsModel()
        gyms.select(home)
        let model = fixture.logSheetModel(for: exercise, on: atHome, editing: entry, gyms: gyms)

        model.select(atAway)

        // Fixing a three-week-old entry from your couch must not relabel what you log
        // next (SPEC §6.4).
        #expect(gyms.currentGym === home)
    }

    @Test("Changing an entry's machine moves it, numbers untouched, no confirmation")
    func changingAnEntrysMachineMovesIt() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let wrong = fixture.machine(for: exercise, at: gym, label: "Green")
        let right = fixture.machine(for: exercise, at: gym, label: "Blue")
        fixture.log(wrong, reps: 8, weight: 62.5, on: .days(ago: 21))
        fixture.log(right, reps: 5, weight: 140, on: .days(ago: 1))
        try fixture.save()
        let entry = try #require(wrong.entries?.first)

        let model = fixture.logSheetModel(for: exercise, on: wrong, editing: entry)
        model.select(right)

        // An edit keeps the numbers you are correcting: the machine is the label, not
        // the lift (SPEC §6.6).
        #expect(model.reps == 8)
        #expect(model.weight == 62.5)

        model.save()

        #expect(entry.machine === right)
        #expect(wrong.entries?.isEmpty == true)
        #expect(right.entries?.count == 2)
    }

    // MARK: - The two rows the nav-bar menu does not need

    @Test("The gym you are standing in gets a section even with no machine in it")
    func theCurrentGymAlwaysGetsASection() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let known = fixture.gym("Fitness X")
        let standingIn = fixture.gym("Holiday Gym")
        fixture.gym("Old Barn")
        let machine = fixture.machine(for: exercise, at: known, label: "Green")
        try fixture.save()

        let gyms = fixture.gymsModel()
        gyms.select(standingIn)
        let model = fixture.logSheetModel(for: exercise, on: machine, gyms: gyms)

        // The hole `New machine here` closes: the first gym-bound log at a gym with no
        // machine for this exercise (SPEC §6.4). Its section has to be there to tap —
        // and no further, or the flat one-decision picker becomes a list to walk down.
        #expect(model.machineMenu.sections.map(\.title) == ["Holiday Gym", "Fitness X"])
    }

    @Test("A gym made from New gym… gets a section to make its machine in")
    func aNewGymGetsASection() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gyms = fixture.gymsModel()
        let model = fixture.logSheetModel(for: exercise, gyms: gyms)
        #expect(model.machineMenu.isEmpty)

        let gym = try #require(gyms.create(named: "Holiday Gym"))
        model.gymCreated(gym)

        // Otherwise the row at the bottom of the picker is a door onto nothing.
        #expect(model.machineMenu.sections.map(\.title) == ["Holiday Gym"])
    }

    @Test("New machine here resolves the sheet to it with no second decision")
    func newMachineHereResolvesTheSheet() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        try fixture.save()

        let gyms = fixture.gymsModel()
        let model = fixture.logSheetModel(for: exercise, gyms: gyms)
        #expect(model.canSave == false)

        model.createMachine(at: gym, named: "By the window")

        #expect(model.machineCaption == "By the window · Fitness X")
        model.advance()
        model.type(.digit(6))
        model.type(.digit(0))
        #expect(model.canSave)
        model.save()

        let saved = try #require(exercise.machines?.first)
        #expect(saved.label == "By the window")
        #expect(saved.entries?.count == 1)
        // Making a machine while logging is standing in that gym (SPEC §6.4).
        #expect(gyms.currentGym === gym)
    }

    @Test("Skipping the name makes an Unlabelled machine")
    func skippingTheNameMakesAnUnlabelledMachine() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")

        let model = fixture.logSheetModel(for: exercise)
        model.createMachine(at: gym, named: nil)

        // A machine is often just the leg press by the window with nothing written on
        // it, so the fallback is a real word (SPEC §7.5).
        #expect(model.machineCaption == "Unlabelled · Fitness X")
    }

    @Test("A machine made mid-edit does not move the current gym")
    func aMachineMadeMidEditDoesNotMoveTheCurrentGym() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let home = fixture.gym("Fitness X")
        let away = fixture.gym("Holiday Gym")
        let atHome = fixture.machine(for: exercise, at: home, label: "Green")
        fixture.log(atHome, reps: 8, weight: 60, on: .days(ago: 21))
        try fixture.save()
        let entry = try #require(atHome.entries?.first)

        let gyms = fixture.gymsModel()
        gyms.select(home)
        let model = fixture.logSheetModel(for: exercise, on: atHome, editing: entry, gyms: gyms)

        model.createMachine(at: away, named: nil)
        model.save()

        #expect(entry.machine?.gym === away)
        #expect(gyms.currentGym === home)
    }

    @Test("A free-weight sheet makes no machine and resolves none")
    func aFreeWeightSheetMakesNoMachine() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Squat")
        let gym = fixture.gym("Fitness X")

        let model = fixture.logSheetModel(for: exercise)
        model.createMachine(at: gym, named: "Nope")

        #expect(model.machine == nil)
        #expect(exercise.machines?.isEmpty == true)
    }
}
