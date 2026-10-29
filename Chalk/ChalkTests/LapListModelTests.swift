import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The endurance log sheet: a grid shaped like the watch's lap list (SPEC §13.7).
///
/// The two an implementer gets wrong: **a new row seeds from the row above**, not from
/// the last saved entry — the block you are typing is the better guess — and **0 % is
/// an incline**, seeded like any other number and never defaulted to 1 %. And Save
/// writes **one entry per row**: nothing groups them once saved.
@Suite("Lap-list log sheet")
struct LapListModelTests {

    // MARK: - Seeding

    @Test("The first row is seeded from the erg's most recent valid interval")
    func theFirstRowSeedsFromTheLastValidInterval() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 300, intensity: 14.0, incline: 1, average: 150, peak: 158, on: .days(ago: 9))
        fixture.interval(treadmill, duration: 360, intensity: 15.0, incline: 1.5, average: 164, peak: 170, on: .days(ago: 2))
        // Newer, but not a valid interval: no duration.
        fixture.interval(treadmill, duration: 0, intensity: 16.0, average: 170, peak: 175, on: .days(ago: 1))

        let model = fixture.lapListModel(for: treadmill)

        #expect(model.drawn == ["6:00 | 15.0 | 1.5 | 164 | 170"])
        #expect(model.focus == .init(row: 0, field: .duration))
    }

    @Test("A first-ever block opens blank")
    func aFirstEverBlockOpensBlank() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)

        let model = fixture.lapListModel(for: rower)

        #expect(model.columns == [.duration, .intensity, .averageHeartRate, .peakHeartRate])
        #expect(model.drawn == [" |  |  | "])
        #expect(model.canSave == false)
    }

    @Test("0 % is seeded as a value, never defaulted to 1 %")
    func aZeroInclineIsSeeded() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 12.0, incline: 0, average: 150, peak: 158)

        let model = fixture.lapListModel(for: treadmill)

        #expect(model.drawn == ["6:00 | 12.0 | 0 | 150 | 158"])
        #expect(model.canSave)
    }

    @Test("A new row is seeded from the row above, not from the last saved entry")
    func aNewRowSeedsFromTheRowAbove() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 15.0, incline: 1, average: 164, peak: 170)

        let model = fixture.lapListModel(for: treadmill)
        model.type("300")
        model.next()
        model.type("16.0")
        model.addRow()

        #expect(model.drawn == [
            "3:00 | 16.0 | 1 | 164 | 170",
            "3:00 | 16.0 | 1 | 164 | 170",
        ])
        #expect(model.focus == .init(row: 1, field: .duration))
    }

    @Test("Typing in a cell replaces its seed; a stray tap does not")
    func typingReplacesTheSeed() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 152, peak: 160)

        let model = fixture.lapListModel(for: bike)
        model.select(.init(row: 0, field: .intensity))
        model.type("2")
        #expect(model.text(.init(row: 0, field: .intensity)) == "2")
        model.type("50")
        model.next()
        #expect(model.text(.init(row: 0, field: .intensity)) == "250")

        // Delete on a seed blanks it; leaving with nothing typed puts the seed back.
        model.type("⌫")
        #expect(model.text(.init(row: 0, field: .averageHeartRate)) == "")
        model.next()
        #expect(model.drawn == ["10:00 | 250 | 152 | 160"])
    }

    // MARK: - Walking the grid

    @Test("Next walks the cells left to right and becomes New row at the end of the last row")
    func nextWalksTheGrid() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 152, peak: 160)
        let model = fixture.lapListModel(for: bike)

        var walked: [String] = [model.focusTitle]
        for _ in 0..<3 {
            #expect(model.nextIsNewRow == false)
            model.next()
            walked.append(model.focusTitle)
        }
        #expect(walked == [
            "Row 1 · Duration", "Row 1 · Power", "Row 1 · Average heart rate", "Row 1 · Peak heart rate",
        ])
        #expect(model.nextIsNewRow)

        model.next()

        #expect(model.rows.count == 2)
        #expect(model.focusTitle == "Row 2 · Duration")
    }

    @Test("A heart rate's last digit and a speed's tenth move on by themselves")
    func completeValuesMoveOn() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        let model = fixture.lapListModel(for: treadmill)
        model.select(.init(row: 0, field: .intensity))

        model.type("15")
        #expect(model.focus.field == .intensity)
        model.type(".0")
        #expect(model.focus.field == .incline)

        model.select(.init(row: 0, field: .averageHeartRate))
        model.type("16")
        #expect(model.focus.field == .averageHeartRate)
        model.type("4")
        #expect(model.focus.field == .peakHeartRate)
        // Two digits are a whole heart rate where no third could follow.
        model.select(.init(row: 0, field: .averageHeartRate))
        model.type("95")
        #expect(model.focus.field == .peakHeartRate)
        // The last cell of the last row never adds a row by itself.
        model.type("170")
        #expect(model.focus == .init(row: 0, field: .peakHeartRate))
        #expect(model.rows.count == 1)
    }

    // MARK: - Formats

    @Test("Times fill from the right, h:mm:ss from an hour, and are never snapped")
    func timesFillFromTheRight() throws {
        let fixture = try LibraryFixture()
        let model = fixture.lapListModel(for: fixture.erg("BikeErg", unit: .watts, kind: .freeWeight))
        let time = LapListModel.Cell(row: 0, field: .duration)

        model.type("6")
        #expect(model.text(time) == "0:06")
        model.type("0")
        #expect(model.text(time) == "0:60")
        model.type("0")
        #expect(model.text(time) == "6:00")
        #expect(model.decimalIsDead)

        model.select(time)
        model.type("602")
        model.next()
        #expect(model.text(time) == "6:02")

        model.select(time)
        model.type("10000")
        model.next()
        #expect(model.text(time) == "1:00:00")
    }

    @Test("A split takes a tenth after the decimal key")
    func aSplitTakesATenth() throws {
        let fixture = try LibraryFixture()
        let model = fixture.lapListModel(for: fixture.erg("Rower", unit: .split, kind: .freeWeight))
        let split = LapListModel.Cell(row: 0, field: .intensity)
        model.select(split)

        #expect(model.decimalIsDead == false)
        model.type("147.5")
        #expect(model.text(split).decimalPoint == "1:47.5")
        model.next()
        #expect(model.text(split).decimalPoint == "1:47.5")

        model.select(split)
        model.type("150.0")
        model.next()
        // A trailing `.0` is trimmed.
        #expect(model.text(split) == "1:50")
    }

    @Test("The decimal key is dead for watts and level")
    func theDecimalIsDeadForWattsAndLevel() throws {
        let fixture = try LibraryFixture()
        for unit in [ErgUnit.watts, .level] {
            let erg = fixture.erg("Erg", unit: unit, kind: .freeWeight)
            fixture.interval(erg, duration: 600, intensity: 12, average: 150, peak: 158)
            let model = fixture.lapListModel(for: erg)
            let intensity = LapListModel.Cell(row: 0, field: .intensity)
            model.select(intensity)

            #expect(model.decimalIsDead)
            model.type(".")
            // Refused, so the seed stands and nothing counts as typed.
            #expect(model.text(intensity) == "12")
            #expect(model.isTouched == false)
        }
    }

    @Test("Speed takes 0.1 km/h and refuses an off-step value")
    func speedRefusesOffStepValues() {
        var speed = EnduranceInput(.intensity, unit: .speed, value: 14.5)

        #expect(speed.type(.digit(1)) == .typed)
        #expect(speed.type(.digit(5)) == .typed)
        #expect(speed.type(.decimal) == .typed)
        #expect(speed.type(.digit(0)) == .complete)
        #expect(speed.type(.digit(5)) == .refused)
        speed.settle()

        #expect(speed.value == 15.0)
        #expect(speed.text.decimalPoint == "15.0")
    }

    @Test("Incline goes in 0.5 % steps from 0")
    func inclineGoesInHalfSteps() throws {
        let fixture = try LibraryFixture()
        let model = fixture.lapListModel(for: fixture.erg("Treadmill", kind: .freeWeight))
        let incline = LapListModel.Cell(row: 0, field: .incline)
        model.select(incline)

        model.type("1.3")
        #expect(model.text(incline).decimalPoint == "1.")
        model.type("5")
        model.next()
        #expect(model.text(incline).decimalPoint == "1.5")

        model.select(incline)
        model.type("0")
        model.next()
        #expect(model.text(incline) == "0")
    }

    // MARK: - Validation

    @Test("Save reads Save N and waits for every row to be complete and valid")
    func saveCountsTheRowsAndWaitsForAllOfThem() throws {
        let fixture = try LibraryFixture()
        let model = fixture.lapListModel(for: fixture.erg("Rower", unit: .split, kind: .freeWeight))

        #expect(model.saveTitle == "Save")
        model.type("400")
        model.next()
        model.type("150")
        model.next()
        model.type("162")
        #expect(model.canSave == false)
        model.type("170")
        #expect(model.canSave)

        model.next()
        model.next()
        #expect(model.saveTitle == "Save 2")
        #expect(model.canSave)

        // A blank cell blocks.
        model.select(.init(row: 1, field: .intensity))
        model.type("⌫")
        #expect(model.canSave == false)
        // So does a zero.
        model.type("0")
        #expect(model.canSave == false)
        model.type("148")
        #expect(model.canSave)
    }

    @Test("A peak below the average outlines both heart rates in red and says why")
    func aPeakBelowTheAverageIsFlagged() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 152, peak: 160)
        let model = fixture.lapListModel(for: bike)
        let average = LapListModel.Cell(row: 0, field: .averageHeartRate)
        let peak = LapListModel.Cell(row: 0, field: .peakHeartRate)
        model.select(peak)

        // Mid-typing is not judged: `1` is on its way to a heart rate.
        model.type("1")
        #expect(model.isFlagged(peak) == false)
        #expect(model.line == nil)

        model.type("48")

        #expect(model.isFlagged(average))
        #expect(model.isFlagged(peak))
        #expect(model.isFlagged(.init(row: 0, field: .intensity)) == false)
        #expect(model.line == .problem("Peak can't be below the average"))
        #expect(model.canSave == false)
    }

    @Test("Heart rates outside 40–230 block Save")
    func heartRatesOutsideTheRangeBlockSave() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 152, peak: 160)
        let model = fixture.lapListModel(for: bike)
        let peak = LapListModel.Cell(row: 0, field: .peakHeartRate)

        model.select(peak)
        model.type("240")
        #expect(model.isFlagged(peak))
        #expect(model.line == .problem("Heart rates are 40–230 bpm"))
        #expect(model.canSave == false)

        model.select(.init(row: 0, field: .averageHeartRate))
        model.type("39")
        model.select(peak)
        model.type("230")
        #expect(model.canSave == false)
        model.select(.init(row: 0, field: .averageHeartRate))
        model.type("40")
        #expect(model.canSave)
    }

    // MARK: - The line under the grid

    @Test("The line under the grid is the focused row's zone")
    func theLineFollowsTheFocusedRow() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 164, peak: 170)
        let model = fixture.lapListModel(for: bike)

        #expect(model.line == .zone("Z4 · 158–169 bpm"))

        model.addRow()
        model.select(.init(row: 1, field: .peakHeartRate))
        model.type("180")
        model.select(.init(row: 1, field: .averageHeartRate))
        model.type("172")
        #expect(model.line == .zone("Z5 · 170+ bpm"))
        model.select(.init(row: 1, field: .averageHeartRate))
        model.type("110")
        #expect(model.line == .zone("Z1 · below 117 bpm"))
        model.select(.init(row: 0, field: .duration))
        #expect(model.line == .zone("Z4 · 158–169 bpm"))
        // A boundary goes up.
        model.select(.init(row: 0, field: .averageHeartRate))
        model.type("140")
        #expect(model.line == .zone("Z3 · 140–157 bpm"))
    }

    @Test("Without zones the line is blank, not a prompt")
    func withoutZonesTheLineIsBlank() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 164, peak: 170)
        let model = fixture.lapListModel(for: bike)

        #expect(model.line == nil)
        #expect(model.canSave)
    }

    // MARK: - Rows

    @Test("Every row can be deleted but the last remaining one")
    func everyRowButTheLastCanBeDeleted() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 152, peak: 160)
        let model = fixture.lapListModel(for: bike)
        #expect(model.canDeleteRows == false)

        model.addRow()
        model.type("300")
        model.addRow()
        model.type("200")
        #expect(model.canDeleteRows)

        model.deleteRow(1)
        #expect(model.drawn == ["10:00 | 210 | 152 | 160", "2:00 | 210 | 152 | 160"])
        #expect(model.focus.row == 1)

        model.deleteRow(1)
        #expect(model.drawn == ["10:00 | 210 | 152 | 160"])
        #expect(model.focus.row == 0)
        #expect(model.canDeleteRows == false)

        model.deleteRow(0)
        #expect(model.rows.count == 1)
    }

    // MARK: - Cancel

    @Test("An untouched sheet closes without asking; once typed, Cancel asks")
    func cancelAsksOnlyOnceTouched() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 152, peak: 160)
        let model = fixture.lapListModel(for: bike)

        // Walking the cells is not typing.
        model.next()
        model.select(.init(row: 0, field: .peakHeartRate))
        model.select(.init(row: 0, field: .duration))
        #expect(model.isTouched == false)

        model.type("5")
        #expect(model.isTouched)
        #expect(model.discardConfirmation == "Discard this entry?")
    }

    @Test("Adding a row touches the sheet, and the question counts the rows")
    func addingARowTouchesTheSheet() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("BikeErg", unit: .watts, kind: .freeWeight)
        fixture.interval(bike, duration: 600, intensity: 210, average: 152, peak: 160)
        let model = fixture.lapListModel(for: bike)

        model.addRow()
        model.addRow()
        model.addRow()
        model.addRow()

        #expect(model.isTouched)
        #expect(model.discardConfirmation == "Discard 5 entries?")
    }

    // MARK: - Save

    @Test("Save writes exactly one entry per row, with the typed values")
    func saveWritesOneEntryPerRow() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 14.5, incline: 1, average: 160, peak: 167, on: .days(ago: 3))
        try fixture.save()
        var saved = 0
        let model = fixture.lapListModel(for: treadmill) { saved += 1 }

        model.type("602")
        model.next()
        model.type("15.0")
        model.next()
        model.type("156164")
        model.next()
        model.select(.init(row: 1, field: .averageHeartRate))
        model.type("163170")
        model.addRow()
        model.type("300")
        model.next()
        model.type("16.0")
        model.type("0")
        model.next()
        model.type("167174")
        #expect(model.saveTitle == "Save 3")
        model.save()

        #expect(saved == 1)
        let entries = try fixture.afterRelaunch()
            .fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date)]))
            .filter { $0.date > .days(ago: 1) }
        #expect(entries.map(\.written) == [
            "362 15.0 1.0 156 164",
            "362 15.0 1.0 163 170",
            "180 16.0 0.0 167 174",
        ])
        #expect(entries.allSatisfy { $0.exercise?.id == treadmill.id && $0.machine == nil })
        // The last lap is the most recent entry, so the next block seeds from it.
        let next = fixture.lapListModel(for: treadmill)
        #expect(next.drawn == ["3:00 | 16.0 | 0 | 167 | 174"])
    }

    // MARK: - The haptic a save plays (SPEC §15.4)

    @Test("A block plays the success tap, once per Save")
    func aBlockPlaysTheSuccessTapOnce() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 14.0, average: 164, on: .days(ago: 2))

        let model = fixture.lapListModel(for: treadmill)
        model.addRow()

        #expect(model.save() == .saved)
    }

    @Test("A block that reaches the goal plays the goal's haptic instead")
    func aBlockThatReachesTheGoalPlaysItsHaptic() throws {
        let fixture = try LibraryFixture()
        fixture.zones(120, 140, 155, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 14.0, average: 164, on: .days(ago: 2))
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 15.0, incline: 0, at: .days(ago: 5))

        let model = fixture.lapListModel(for: treadmill)
        model.select(.init(row: 0, field: .intensity))
        model.type("16.0")

        // Two visits at 6:00 in Z4, 14.0 and 16.0: the point's mean is the goal's 15.0.
        #expect(model.save() == .reachedGoal)
    }

    @Test("A block past a goal already reached plays the success tap")
    func aBlockPastAReachedGoalPlaysTheSuccessTap() throws {
        let fixture = try LibraryFixture()
        fixture.zones(120, 140, 155, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 16.0, average: 164, on: .days(ago: 2))
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 15.0, incline: 0, at: .days(ago: 5))

        let model = fixture.lapListModel(for: treadmill)

        #expect(model.save() == .saved)
    }

    @Test("Save does nothing while a row is invalid")
    func saveRefusesAnInvalidRow() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        var saved = 0
        let model = fixture.lapListModel(for: rower) { saved += 1 }

        model.type("400")
        model.save()

        #expect(saved == 0)
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).isEmpty)
    }
}

// MARK: - Helpers

extension LapListModel {
    /// Each row as the grid draws it, cells joined by ` | `, with the decimal written `.`
    /// whatever the test machine's locale.
    var drawn: [String] {
        rows.indices.map { row in
            columns.map { text(Cell(row: row, field: $0)) }.joined(separator: " | ").decimalPoint
        }
    }

    /// Types `keys` on the keypad: digits, `.` for the decimal key and `⌫` for delete.
    func type(_ keys: String) {
        for key in keys {
            switch key {
            case ".": type(TwoStageNumber.Key.decimal)
            case "⌫": type(TwoStageNumber.Key.delete)
            default: type(TwoStageNumber.Key.digit(key.wholeNumberValue!))
            }
        }
    }
}

extension String {
    /// This text with the locale's decimal separator written as `.`.
    var decimalPoint: String {
        replacingOccurrences(of: WeightText.decimalSeparator, with: ".")
    }
}

private extension Entry {
    var written: String {
        "\(duration) \(intensity) \(incline) \(averageHeartRate) \(peakHeartRate)"
    }
}
