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
}
