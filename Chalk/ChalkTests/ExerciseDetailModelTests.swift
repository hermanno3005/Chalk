import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The exercise detail screen's state (SPEC §5.1–5.2, §5.4–5.5).
///
/// The sticky selection is the one an implementer gets wrong: `chartXSelection` clears
/// its binding the moment a finger lifts, so a model that stores it straight through
/// snaps the readout back and no rep count but the default can be held.
@Suite("Exercise detail model")
struct ExerciseDetailModelTests {

    // MARK: - The scrub readout

    @Test("The selection defaults to 5 reps")
    func selectionDefaultsToFiveReps() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 8, weight: 60)

        let model = fixture.detailModel(for: exercise)

        #expect(model.selectedReps == 5)
        #expect(model.readout?.weight == 60)
    }

    @Test("The readout counts every entry at or above the selected rep count")
    func readoutCountsTheEntriesBehindTheCell() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 3, weight: 100)
        fixture.log(exercise, reps: 5, weight: 90)
        fixture.log(exercise, reps: 8, weight: 80)

        let model = fixture.detailModel(for: exercise)

        #expect(model.readout?.reps == 5)
        #expect(model.readout?.weight == 90)
        #expect(model.readout?.entriesBehind == 2)
    }

    @Test("The selection stays where the finger lifted")
    func selectionIsSticky() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 10, weight: 70)

        let model = fixture.detailModel(for: exercise)
        model.select(9)
        // chartXSelection clears its binding on lift.
        model.select(nil)

        #expect(model.selectedReps == 9)
    }

    @Test("A selection off the axis is pulled back onto it")
    func selectionIsClampedToTheAxis() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 20, weight: 40)

        let model = fixture.detailModel(for: exercise)
        model.select(19)
        #expect(model.selectedReps == 12)

        model.select(0)
        #expect(model.selectedReps == 1)
        #expect(model.readout?.weight == 40)
    }

    @Test("A rep count the curve has not reached reads as an absence, not a number")
    func anUnprovenCellHasNoWeight() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        // Triples only: backfill floors 1 through 3 and nothing above.
        fixture.log(exercise, reps: 3, weight: 100)

        let model = fixture.detailModel(for: exercise)

        // The default holds at 5 even though nothing proves it — the screen says so
        // rather than sliding to a rep count that does have a number.
        #expect(model.selectedReps == 5)
        #expect(model.readout?.weight == nil)
        #expect(model.readout?.entriesBehind == 0)

        model.select(3)
        #expect(model.readout?.weight == 100)
    }

    // MARK: - Zero entries

    @Test("A newly created exercise draws no curve, no ghost and no readout")
    func zeroEntriesDrawsNothing() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")

        let model = fixture.detailModel(for: exercise)

        #expect(model.hasCurve == false)
        #expect(model.readout == nil)
        #expect(model.curve.best.isEmpty)
        #expect(model.curve.ghost.isEmpty)
    }

    @Test("The empty state carries the hint, and the curve is still empty")
    func theEmptyStateCarriesTheHint() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(sibling, reps: 5, weight: 55, on: .days(ago: 2))

        let model = fixture.detailModel(for: exercise)
        model.select(here)

        #expect(model.hint?.text == "\(55.0.kilogramsText) kg × 5 on Hammer Strength")
        // Text, never a dimmed curve: nothing the sibling lifted reaches the chart
        // (SPEC §5.4).
        #expect(model.hasCurve == false)
        #expect(model.curve.best.isEmpty)
        #expect(model.curve.ghost.isEmpty)
    }

    @Test("A machine with a curve of its own carries no hint")
    func aScopedMachineWithHistoryCarriesNoHint() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(here, reps: 5, weight: 40, on: .days(ago: 1))
        fixture.log(sibling, reps: 5, weight: 55, on: .days(ago: 2))

        let model = fixture.detailModel(for: exercise)
        model.select(here)

        #expect(model.hint == nil)
    }

    @Test("A free-weight exercise with nothing logged gets bare text")
    func aFreeWeightEmptyStateIsBareText() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")

        #expect(fixture.detailModel(for: exercise).hint == nil)
    }

    @Test("The hint follows the qualifier from machine to machine")
    func theHintFollowsTheQualifier() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let logged = fixture.machine(for: exercise, at: gym, label: "By the window")
        let fresh = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(logged, reps: 5, weight: 55, on: .days(ago: 2))

        let model = fixture.detailModel(for: exercise)
        // Opens on the machine with the history, which speaks for itself.
        #expect(model.machine === logged)
        #expect(model.hint == nil)

        model.select(fresh)

        #expect(model.hint?.text == "\(55.0.kilogramsText) kg × 5 on By the window")
    }

    // MARK: - The overflow menu

    @Test("Renaming keeps the exercise's identity and survives relaunch")
    func renamePersists() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Pres")
        try fixture.save()
        let id = exercise.id

        let model = fixture.detailModel(for: exercise)
        model.rename(to: "  Bench Press  ")

        #expect(model.name == "Bench Press")
        #expect(exercise.id == id)

        let reopened = try fixture.afterRelaunch()
        #expect(try reopened.fetch(FetchDescriptor<Exercise>()).map(\.name) == ["Bench Press"])
    }

    @Test("A blank rename is ignored")
    func blankRenameIsIgnored() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")

        let model = fixture.detailModel(for: exercise)
        model.rename(to: "   ")

        #expect(model.name == "Bench Press")
    }

    @Test("The delete confirmation is the outcome with its entry count")
    func deleteConfirmationCarriesTheCount() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 60)
        fixture.log(exercise, reps: 5, weight: 65)

        #expect(fixture.detailModel(for: exercise).deleteConfirmation
            == "Delete Bench Press and its 2 entries?")
    }

    @Test("One entry is not phrased as two")
    func deleteConfirmationInflects() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 60)

        #expect(fixture.detailModel(for: exercise).deleteConfirmation
            == "Delete Bench Press and its 1 entry?")
    }

    @Test("An exercise with nothing logged is not asked about entries")
    func deleteConfirmationOmitsAnEmptyCount() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")

        #expect(fixture.detailModel(for: exercise).deleteConfirmation == "Delete Bench Press?")
    }

    @Test("Deleting cascades to the entries and leaves the library behind it")
    func deleteCascadesAndRefreshesTheLibrary() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        let survivor = fixture.exercise("Squat")
        fixture.log(exercise, reps: 5, weight: 60)
        fixture.log(survivor, reps: 5, weight: 100)
        try fixture.save()

        let library = fixture.libraryModel()
        let model = fixture.detailModel(for: exercise, refreshing: library)
        model.delete()

        #expect(library.content.drawn == "grid Ungrouped[Squat]")
        let reopened = try fixture.afterRelaunch()
        #expect(try reopened.fetch(FetchDescriptor<Exercise>()).map(\.name) == ["Squat"])
        #expect(try reopened.fetch(FetchDescriptor<Entry>()).map(\.weight) == [100])
    }

    // MARK: - The goal line

    @Test("A goal shows its gap under the readout")
    func theGoalLineInItsGapState() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 80, on: .days(ago: 10))
        GoalScope.exercise(exercise).set(reps: 5, weight: 140, at: .days(ago: 5))
        fixture.log(exercise, reps: 5, weight: 100, on: .days(ago: 1))

        let line = try #require(fixture.detailModel(for: exercise).goalLine)

        #expect(line.text == "Goal 140 × 5 · 40 kg to go")
        #expect(!line.isReached)
        #expect(line.progress == 20.0 / 60.0)
    }

    @Test("A reached goal stays, greyed, and says so")
    func theGoalLineInItsReachedState() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        GoalScope.exercise(exercise).set(reps: 5, weight: 140, at: .days(ago: 5))
        fixture.log(exercise, reps: 6, weight: 142.5, on: .days(ago: 1))

        let line = try #require(fixture.detailModel(for: exercise).goalLine)

        #expect(line.text == "Goal 140 × 5 · reached")
        #expect(line.isReached)
        #expect(line.progress == 1)
    }

    @Test("Without a goal there is no line")
    func noGoalNoLine() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 100)

        #expect(fixture.detailModel(for: exercise).goalLine == nil)
    }

    @Test("A partly filled goal is no goal on screen")
    func aPartialGoalShowsNoLine() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        exercise.goalReps = 5
        exercise.goalWeight = 140

        #expect(fixture.detailModel(for: exercise).goalLine == nil)
    }

    @Test("The zero-entry screen carries the goal, with the whole weight to go")
    func theGoalLineOnTheZeroEntryScreen() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        GoalScope.exercise(exercise).set(reps: 5, weight: 140)

        let model = fixture.detailModel(for: exercise)

        #expect(!model.hasCurve)
        #expect(model.goalLine?.text == "Goal 140 × 5 · 140 kg to go")
        #expect(model.goalLine?.progress == 0)
    }

    @Test("Setting and clearing from the sheet puts the line back in step")
    func theSheetRefreshesTheLine() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 100)
        let model = fixture.detailModel(for: exercise)

        let setting = try #require(model.goalSheet())
        setting.number.advance()
        for digit in [1, 2, 0] { setting.number.type(.digit(digit)) }
        setting.setGoal()
        #expect(model.goalLine?.text == "Goal 120 × 5 · 20 kg to go")
        #expect(model.goalMenuLabel == "Change goal…")

        try #require(model.goalSheet()).clearGoal()
        #expect(model.goalLine == nil)
        #expect(model.goalMenuLabel == "Set a goal…")
    }

    @Test("Setting and clearing from the sheet puts the resume card's ring back in step")
    func theSheetRefreshesTheResumeCard() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 100)
        try fixture.save()
        let library = fixture.libraryModel()
        let model = fixture.detailModel(for: exercise, refreshing: library)
        #expect(library.resume?.goal == nil)

        let setting = try #require(model.goalSheet())
        setting.number.advance()
        for digit in [1, 2, 0] { setting.number.type(.digit(digit)) }
        setting.setGoal()
        #expect(library.resume?.goal?.text == "120 × 5")

        try #require(model.goalSheet()).clearGoal()
        #expect(library.resume?.goal == nil)
    }

    @Test("A downward edit un-reaches the goal on the next read")
    func aDownwardEditUnreaches() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        GoalScope.exercise(exercise).set(reps: 5, weight: 140, at: .days(ago: 5))
        fixture.log(exercise, reps: 5, weight: 140, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.detailModel(for: exercise)
        #expect(model.goalLine?.isReached == true)

        let history = try #require(model.historySheet())
        let edit = history.editSheet(for: try #require(history.rows.first))
        edit.advance()
        edit.tapNumber()
        for digit in [1, 3, 0] { edit.type(.digit(digit)) }
        edit.save()

        #expect(model.goalLine?.text == "Goal 140 × 5 · 10 kg to go")
        #expect(model.goalLine?.isReached == false)
    }

    // MARK: - The goal in the overflow

    @Test("The overflow offers to set a goal, then to change it")
    func theOverflowLabel() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")

        #expect(fixture.detailModel(for: exercise).goalMenuLabel == "Set a goal…")

        GoalScope.exercise(exercise).set(reps: 5, weight: 140)
        #expect(fixture.detailModel(for: exercise).goalMenuLabel == "Change goal…")
    }

    @Test("A gym-bound exercise with no machine offers no goal at all")
    func noMachineNoGoal() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)

        let model = fixture.detailModel(for: exercise)

        #expect(model.goalMenuLabel == nil)
        #expect(model.goalSheet() == nil)
        #expect(model.goalLine == nil)
    }

    @Test("Switching machines switches the goal line with it")
    func theQualifierSwitchesTheGoal() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let home = fixture.machine(for: exercise, at: fixture.gym("Home"), label: "Home")
        let away = fixture.machine(for: exercise, at: fixture.gym("Away"), label: "Away")
        fixture.log(home, reps: 8, weight: 150, on: .days(ago: 1))
        fixture.log(away, reps: 8, weight: 120, on: .days(ago: 2))
        GoalScope.machine(home).set(reps: 8, weight: 200)

        let model = fixture.detailModel(for: exercise)
        model.select(home)
        #expect(model.goalLine?.text == "Goal 200 × 8 · 50 kg to go")

        model.select(away)
        #expect(model.goalLine == nil)
        #expect(model.goalMenuLabel == "Set a goal…")
    }
}
