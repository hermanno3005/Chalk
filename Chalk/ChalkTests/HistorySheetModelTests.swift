import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The `reps >= N` history sheet, and the edit mode it opens (SPEC §5.6, §6.6).
///
/// The one an implementer gets wrong: **the sheet mirrors the derivation rather than
/// listing the entries at exactly N reps.** A backfilled cell is set by a higher-rep
/// lift, so that lift has to be in the list — and flagged — or the sheet cannot explain
/// the number it was opened from.
@Suite("History sheet model")
struct HistorySheetModelTests {

    // MARK: - What the sheet lists

    @Test("The sheet lists every entry at or above the rep count, newest first")
    func listsTheEntriesBehindTheCell() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 8, weight: 60, on: .days(ago: 9))
        fixture.log(exercise, reps: 5, weight: 75, on: .days(ago: 2))
        fixture.log(exercise, reps: 3, weight: 90, on: .days(ago: 1))
        fixture.log(exercise, reps: 12, weight: 50, on: .days(ago: 30))

        let model = fixture.historySheetModel(for: exercise, atLeast: 5)

        // The 3-rep entry cannot set best[5], so it is not part of the explanation.
        #expect(model.rows.map(\.lift) == ["5 × \(kg(75)) kg", "8 × \(kg(60)) kg", "12 × \(kg(50)) kg"])
    }

    @Test("The list is exactly the count the readout promised")
    func theListMirrorsTheReadout() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 3, weight: 100)
        fixture.log(exercise, reps: 5, weight: 90)
        fixture.log(exercise, reps: 8, weight: 80)

        let detail = fixture.detailModel(for: exercise)
        let model = fixture.historySheetModel(for: exercise, atLeast: detail.selectedReps)

        #expect(model.rows.count == detail.readout?.entriesBehind)
    }

    @Test("An unproven cell has no history to open")
    func anUnprovenCellOpensNothing() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        // Triples only: the backfill floors 1 through 3 and nothing above.
        fixture.log(exercise, reps: 3, weight: 100)

        let detail = fixture.detailModel(for: exercise)
        detail.select(8)

        #expect(detail.readout?.weight == nil)
        #expect(detail.historySheet() == nil)

        detail.select(3)
        #expect(detail.historySheet()?.rows.count == 1)
    }

    @Test("A row that is not a lift is not history")
    func aZeroedRowIsNotListed() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 75)
        fixture.log(exercise, reps: 5, weight: 0)

        let model = fixture.historySheetModel(for: exercise, atLeast: 5)

        #expect(model.rows.count == 1)
    }

    // MARK: - The flag

    @Test("The flagged entry is the one setting the cell, backfill included")
    func flagsTheEntrySettingTheCell() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 75, on: .days(ago: 1))
        // Eight reps at 80 floors best[5] too, and is what the cell is showing.
        fixture.log(exercise, reps: 8, weight: 80, on: .days(ago: 9))

        let model = fixture.historySheetModel(for: exercise, atLeast: 5)

        #expect(model.rows.filter(\.isBest).map(\.lift) == ["8 × \(kg(80)) kg"])
    }

    @Test("A matched best stays with the entry that set it first")
    func aTieKeepsTheOlderEntry() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 80, on: .days(ago: 30))
        fixture.log(exercise, reps: 5, weight: 80, on: .days(ago: 1))

        let model = fixture.historySheetModel(for: exercise, atLeast: 5)

        #expect(model.rows.map(\.isBest) == [false, true])
    }

    // MARK: - Editing

    @Test("A row opens the log sheet seeded from that entry, not the most recent one")
    func theEditSheetIsSeededFromTheRow() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 75, on: .days(ago: 9))
        fixture.log(exercise, reps: 8, weight: 60, on: .days(ago: 1))

        let model = fixture.historySheetModel(for: exercise, atLeast: 5)
        let older = try #require(model.rows.last)
        let edit = model.editSheet(for: older)

        #expect(edit.reps == 5)
        edit.advance()
        #expect(edit.weight == 75)
        // The date it was logged on, stated rather than offered (SPEC §6.6).
        #expect(edit.dateLabel != nil)
    }

    @Test("Saving an edit writes back in place and re-derives the curve")
    func savingAnEditWritesBackInPlace() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 75, on: .days(ago: 9))
        let detail = fixture.detailModel(for: exercise)

        let model = fixture.historySheetModel(for: exercise, atLeast: 5, onChange: detail.refresh)
        let edit = model.editSheet(for: try #require(model.rows.first))
        edit.advance()
        edit.tapNumber()
        edit.type(.digit(8))
        edit.type(.digit(5))
        edit.save()

        #expect(model.rows.map(\.lift) == ["5 × \(kg(85)) kg"])
        #expect(detail.readout?.weight == 85)

        // In place: one entry, not a second one alongside the first.
        let logged = try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>())
        #expect(logged.map { [Double($0.reps), $0.weight] } == [[5, 85]])
    }

    @Test("The date is not the sheet's to change")
    func anEditLeavesTheDateAlone() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        let logged = Date.days(ago: 9)
        fixture.log(exercise, reps: 5, weight: 75, on: logged)

        let model = fixture.historySheetModel(for: exercise, atLeast: 5)
        let edit = model.editSheet(for: try #require(model.rows.first))
        edit.step(+1)
        edit.advance()
        edit.save()

        let entry = try #require(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).first)
        #expect(entry.reps == 6)
        #expect(entry.date == logged)
    }

    @Test("A saved edit confirms itself on the sheet that is in view")
    func anEditFlashesItsConfirmation() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 75)

        let model = fixture.historySheetModel(for: exercise, atLeast: 5)
        var confirmed = false
        let edit = model.editSheet(for: try #require(model.rows.first)) { confirmed = true }

        edit.advance()
        edit.step(+1)
        edit.save()

        // The detail screen is two layers down behind this list (SPEC §6.7), so the
        // word about the write belongs here.
        #expect(confirmed)
    }

    @Test("Editing reps below the threshold drops the row out of the sheet")
    func anEditCanDropTheRowOutOfItsOwnSheet() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 75, on: .days(ago: 9))
        fixture.log(exercise, reps: 8, weight: 60, on: .days(ago: 1))

        let model = fixture.historySheetModel(for: exercise, atLeast: 5)
        let five = try #require(model.rows.last)
        let edit = model.editSheet(for: five)
        edit.step(-1)
        edit.step(-1)
        edit.advance()
        edit.save()

        // Three reps cannot set best[5]. The filter is behaving, not losing the entry.
        #expect(model.rows.map(\.lift) == ["8 × \(kg(60)) kg"])
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).count == 2)
    }

    @Test("An edit is judged against the rest of your history, not against itself")
    func theVerdictExcludesTheEntryBeingEdited() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 70, on: .days(ago: 30))
        fixture.log(exercise, reps: 5, weight: 100, on: .days(ago: 1))

        let model = fixture.historySheetModel(for: exercise, atLeast: 5)
        let edit = model.editSheet(for: try #require(model.rows.first))
        edit.advance()

        // The 100 kg entry is the one being corrected, so the best it has to beat is
        // the 70 kg behind it — comparing an entry with itself says nothing.
        #expect(edit.verdict == .measured("Beats your 5-rep best by \(kg(30)) kg"))
    }

    // MARK: - Deleting

    @Test("Deleting a row lowers the cell it was setting")
    func deletingARowLowersTheRepMax() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 75, on: .days(ago: 9))
        fixture.log(exercise, reps: 5, weight: 100, on: .days(ago: 1))
        let detail = fixture.detailModel(for: exercise)

        let model = fixture.historySheetModel(for: exercise, atLeast: 5, onChange: detail.refresh)
        model.delete(try #require(model.rows.first))

        #expect(model.rows.map(\.lift) == ["5 × \(kg(75)) kg"])
        #expect(detail.readout?.weight == 75)
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).count == 1)
    }

    @Test("Deleting the last entry returns the exercise to its empty state")
    func deletingTheLastEntryEmptiesTheExercise() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 75)
        let detail = fixture.detailModel(for: exercise)

        let model = fixture.historySheetModel(for: exercise, atLeast: 5, onChange: detail.refresh)
        model.delete(try #require(model.rows.first))

        // The exercise survives; the curve and the ghost have nothing to draw.
        #expect(model.rows.isEmpty)
        #expect(detail.hasCurve == false)
        #expect(detail.readout == nil)
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Exercise>()).count == 1)
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).isEmpty)
    }

    @Test("An emptied sheet has lost the cell it was opened from")
    func anEmptiedSheetIsDone() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 75)

        let model = fixture.historySheetModel(for: exercise, atLeast: 5)
        #expect(model.isEmpty == false)
        model.delete(try #require(model.rows.first))

        #expect(model.isEmpty)
    }
}

/// A weight as this device would write it — the tests assert the sheet's phrasing, not
/// the decimal separator of whichever locale they happen to run in.
private func kg(_ weight: Double) -> String {
    weight.kilogramsText
}
