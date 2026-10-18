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
}
