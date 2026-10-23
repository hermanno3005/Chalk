import Foundation
import Testing

@testable import Chalk

/// `GoalScope.clear()` is the one write that removes a goal, and the unit change, the
/// kind change and the merge all clear through it. **It nils all seven goal fields, both
/// halves' alike** (ADR-0008): a row is one half by construction, so clearing never has
/// to ask which half's goal it holds, and a stray field from the other half can never
/// outlive a clear.
@Suite("Goal scope")
struct GoalScopeTests {

    private let setAt = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("Clearing an exercise's goal nils both halves' fields")
    func clearingAnExerciseNilsAllSeven() {
        let exercise = Exercise(name: "Treadmill", unit: .speed)
        exercise.goalReps = 5
        exercise.goalWeight = 140
        exercise.goalSetAt = setAt
        exercise.goalZone = 4
        exercise.goalDuration = 360
        exercise.goalIntensity = 15.5
        exercise.goalIncline = 1

        GoalScope.exercise(exercise).clear()

        #expect(exercise.goalReps == nil)
        #expect(exercise.goalWeight == nil)
        #expect(exercise.goalSetAt == nil)
        #expect(exercise.goalZone == nil)
        #expect(exercise.goalDuration == nil)
        #expect(exercise.goalIntensity == nil)
        #expect(exercise.goalIncline == nil)
    }

    @Test("Clearing a machine's goal nils both halves' fields")
    func clearingAMachineNilsAllSeven() {
        let machine = Machine(label: "Technogym Run")
        machine.goalReps = 8
        machine.goalWeight = 72.5
        machine.goalSetAt = setAt
        machine.goalZone = 3
        machine.goalDuration = 600
        machine.goalIntensity = 220
        machine.goalIncline = 0.5

        GoalScope.machine(machine).clear()

        #expect(machine.goalReps == nil)
        #expect(machine.goalWeight == nil)
        #expect(machine.goalSetAt == nil)
        #expect(machine.goalZone == nil)
        #expect(machine.goalDuration == nil)
        #expect(machine.goalIntensity == nil)
        #expect(machine.goalIncline == nil)
    }

    @Test("Setting a strength goal leaves the endurance fields alone")
    func settingAStrengthGoalWritesOnlyItsOwnFields() {
        let exercise = Exercise(name: "Bench Press")

        GoalScope.exercise(exercise).set(reps: 5, weight: 140, at: setAt)

        #expect(exercise.goalReps == 5)
        #expect(exercise.goalZone == nil)
        #expect(exercise.goalDuration == nil)
        #expect(exercise.goalIntensity == nil)
        #expect(exercise.goalIncline == nil)
    }

    // MARK: - Endurance

    @Test("Setting an endurance goal writes its four fields and the moment, and nothing of strength's")
    func settingAnEnduranceGoal() {
        let erg = Exercise(name: "Treadmill", unit: .speed)

        GoalScope.exercise(erg).set(zone: 4, duration: 360, intensity: 15.5, incline: 1, at: setAt)

        #expect(erg.goalZone == 4)
        #expect(erg.goalDuration == 360)
        #expect(erg.goalIntensity == 15.5)
        #expect(erg.goalIncline == 1)
        #expect(erg.goalSetAt == setAt)
        #expect(erg.goalReps == nil)
        #expect(erg.goalWeight == nil)
    }

    @Test("An endurance goal on any unit but speed stores no incline")
    func anEnduranceGoalOffSpeedHasNoIncline() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .split)
        let machine = fixture.machine(for: rower, at: fixture.gym("Fitness X"), label: "Concept2")

        GoalScope.machine(machine).set(zone: 3, duration: 600, intensity: 110, incline: 2, at: setAt)

        #expect(machine.goalIncline == nil)
        #expect(machine.goalIntensity == 110)
    }

    @Test("A machine's endurance goal is read in its erg's unit and judged against that machine's entries")
    func readingAMachinesEnduranceGoal() throws {
        let fixture = try LibraryFixture()
        fixture.zones(120, 140, 158, 170)
        let erg = fixture.erg("Treadmill")
        let gym = fixture.gym("Fitness X")
        let machine = fixture.machine(for: erg, at: gym)
        let sibling = fixture.machine(for: erg, at: gym, label: "Other")
        fixture.interval(erg, machine: machine, intensity: 15.1, average: 164)
        fixture.interval(erg, machine: sibling, intensity: 16.0, average: 164)
        try fixture.save()

        GoalScope.machine(machine).set(zone: 4, duration: 360, intensity: 15.5, incline: 0)

        let goal = try #require(GoalScope.machine(machine).enduranceGoal(zones: fixture.heldZones(), distanceUnit: .km))
        #expect(goal.unit == .speed)
        #expect(goal.current == 15.1)
        #expect(GoalScope.machine(sibling).enduranceGoal(zones: fixture.heldZones(), distanceUnit: .km) == nil)
    }

    @Test("A strength goal is never read as an endurance goal, nor a lift's fields as one")
    func aLiftHasNoEnduranceGoal() {
        let exercise = Exercise(name: "Bench Press")
        exercise.goalZone = 4
        exercise.goalDuration = 360
        exercise.goalIntensity = 15.5
        exercise.goalSetAt = setAt

        #expect(GoalScope.exercise(exercise).enduranceGoal(zones: nil, distanceUnit: .km) == nil)
    }
}
