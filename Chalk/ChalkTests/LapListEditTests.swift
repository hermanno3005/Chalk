import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The lap-list grid in edit mode, opened from an erg's history row (SPEC §13.9, §6.6).
///
/// The rules an implementer gets subtly wrong: **an edit writes back in place and leaves
/// the date alone** — it is one row, never a block, so there is no *New row* and no
/// `Save N` — and **an edit is not a visit**: picking another gym's machine never moves
/// the current gym, and saving onto an archived gym's machine never un-archives it.
@Suite("Lap-list edit")
struct LapListEditTests {

    // MARK: - The sheet

    @Test("An edit is one row seeded from the entry, with its date in the title and a plain Save")
    func anEditIsOneSeededRow() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", unit: .speed, kind: .freeWeight)
        let older = fixture.interval(treadmill, duration: 360, intensity: 15.0, incline: 1, average: 164, peak: 170, on: .days(ago: 3))
        fixture.interval(treadmill, duration: 600, intensity: 12.0, average: 150, peak: 160, on: .days(ago: 1))
        try fixture.save()

        let model = fixture.lapListModel(for: treadmill, editing: older)

        #expect(model.drawn == ["6:00 | 15.0 | 1 | 164 | 170"])
        #expect(model.title == "3 days ago")
        #expect(model.saveTitle == "Save")
        #expect(model.canAddRows == false)
        #expect(model.canDeleteRows == false)
    }

    @Test("Next at the end of the row never adds one")
    func nextNeverAddsARow() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        let entry = fixture.interval(rower, duration: 360, intensity: 260, average: 164, peak: 170)
        try fixture.save()

        let model = fixture.lapListModel(for: rower, editing: entry)
        model.select(.init(row: 0, field: .peakHeartRate))

        #expect(model.nextIsNewRow == false)
        model.next()
        model.addRow()
        #expect(model.rows.count == 1)
    }

    @Test("Saving an edit writes back in place and keeps the date")
    func savingAnEditWritesBackInPlace() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        let logged = Date.days(ago: 9)
        let entry = fixture.interval(rower, duration: 360, intensity: 260, average: 164, peak: 170, on: logged)
        try fixture.save()
        var saved = 0

        let model = fixture.lapListModel(for: rower, editing: entry) { saved += 1 }
        model.fill(0, "500", "265", "158", "166")
        model.save()

        let entries = try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>())
        #expect(entries.map(\.written) == ["300 265.0 0.0 158 166"])
        #expect(entries.first?.date == logged)
        #expect(saved == 1)
    }

    @Test("The line under the grid shows the edited row's zone")
    func theLineShowsTheEditedZone() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        let entry = fixture.interval(rower, duration: 360, intensity: 260, average: 164, peak: 170)
        try fixture.save()

        let model = fixture.lapListModel(for: rower, editing: entry)
        #expect(model.line == .zone("Z4 · 158–169 bpm"))

        model.fill(0, "", "", "150")
        #expect(model.line == .zone("Z3 · 140–157 bpm"))
    }

    // MARK: - Cancel

    @Test("Cancel asks Discard changes? only once something changed")
    func cancelAsksOnlyAfterAChange() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        let entry = fixture.interval(rower, duration: 360, intensity: 260, average: 164, peak: 170)
        try fixture.save()

        let model = fixture.lapListModel(for: rower, editing: entry)
        // Typing the same number back over a cell is not a change.
        model.fill(0, "", "260")
        model.next()
        #expect(model.isTouched == false)

        model.fill(0, "", "265")
        model.next()
        #expect(model.isTouched)
        #expect(model.discardConfirmation == "Discard changes?")
    }

    // MARK: - The machine

    @Test("Changing the machine moves the entry, and its row leaves the point's sheet")
    func aMachineChangeMovesTheEntry() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        let gym = fixture.gym("Urban Gym")
        let run = fixture.machine(for: treadmill, at: gym, label: "Technogym Run")
        let excite = fixture.machine(for: treadmill, at: gym, label: "Technogym Excite")
        fixture.interval(treadmill, machine: run, intensity: 15.0, on: .days(ago: 2))
        fixture.interval(treadmill, machine: excite, intensity: 14.0, on: .days(ago: 1))
        try fixture.save()
        let detail = fixture.ergDetailModel(for: treadmill)
        detail.select(run)
        let history = try #require(detail.historySheet())

        let row = try #require(history.rows.first)
        let edit = try #require(history.editSheet(for: row))
        #expect(edit.machineCaption == "Technogym Run · Urban Gym")
        edit.select(excite)
        // A pick is not a re-seed on an edit: the row is the entry being corrected.
        #expect(edit.drawn == ["6:00 | 15.0 | 0 | 164 | 170"])
        edit.save()

        #expect(history.isEmpty)
        // The screen behind is still on the Run, which now holds nothing.
        #expect(detail.isEmpty)
        #expect(run.entries?.isEmpty == true)
        #expect(excite.entries?.count == 2)
    }

    @Test("An edit never moves the current gym or un-archives one")
    func anEditIsNotAVisit() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let urban = fixture.gym("Urban Gym")
        let fitX = fixture.gym("FitX", isArchived: true)
        let run = fixture.machine(for: treadmill, at: urban, label: "Technogym Run")
        let old = fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")
        let entry = fixture.interval(treadmill, machine: run, intensity: 15.0, on: .days(ago: 2))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(urban)

        let model = fixture.lapListModel(for: treadmill, editing: entry, gyms: gyms)
        model.select(old)
        model.save()

        #expect(gyms.currentGym === urban)
        #expect(fitX.isArchived)
        #expect(entry.machine === old)
    }

    @Test("Picking another gym's machine on an edit leaves the current gym where it was")
    func anEditPickLeavesTheGym() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let urban = fixture.gym("Urban Gym")
        let fitX = fixture.gym("FitX")
        let run = fixture.machine(for: treadmill, at: urban, label: "Technogym Run")
        let excite = fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")
        let entry = fixture.interval(treadmill, machine: run, intensity: 15.0)
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(urban)

        let model = fixture.lapListModel(for: treadmill, editing: entry, gyms: gyms)
        model.select(excite)

        #expect(gyms.currentGym === urban)
    }
}

private extension Entry {
    var written: String {
        "\(duration) \(intensity) \(incline) \(averageHeartRate) \(peakHeartRate)"
    }
}
