import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The point's sheet and the over-20:00 list behind the erg readout (SPEC §13.9).
///
/// The rules an implementer gets subtly wrong: **the sheet lists the point's entries from
/// all time**, not just the window the mean reads — the window is a divider, drawn after
/// the tenth *visit* (a calendar day), not the tenth entry — and **the sheet mirrors the
/// point**: an edit that moves an entry off it makes the row vanish, and an emptied
/// point leaves the sheet open and empty rather than closing it.
@Suite("Erg history model")
struct ErgHistoryModelTests {

    // MARK: - The point's sheet

    @Test("The point's sheet lists its entries from all time, newest first, with the divider after the tenth visit")
    func listsThePointFromAllTime() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        // Eleven visits at 6:00 in Z4, a watt apart, the newest day holding two entries.
        for day in 1...11 {
            fixture.interval(rower, duration: 360, intensity: Double(250 + day), average: 164, on: .days(ago: day))
        }
        fixture.interval(rower, duration: 360, intensity: 240, average: 165, on: .days(ago: 1).addingTimeInterval(60))
        // Another point, and another zone: neither is this point's.
        fixture.interval(rower, duration: 600, intensity: 230, average: 164, on: .days(ago: 1))
        fixture.interval(rower, duration: 360, intensity: 200, average: 150, on: .days(ago: 1))
        try fixture.save()

        let detail = fixture.ergDetailModel(for: rower)
        detail.select(duration: 360)
        let model = try #require(detail.historySheet())

        #expect(model.rows.map(\.intensity) == ["240 W", "251 W", "252 W", "253 W", "254 W", "255 W", "256 W", "257 W", "258 W", "259 W", "260 W"])
        #expect(model.older.map(\.intensity) == ["261 W"])
        #expect(ErgHistoryModel.divider == "Older — not in the line")
    }

    @Test("The readout's count is the rows above the divider")
    func theCountMatchesTheReadout() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        // Twelve visits, three of them doubled: 15 entries, 12 inside the window.
        for day in 1...12 {
            fixture.interval(rower, duration: 360, intensity: 260, average: 164, on: .days(ago: day))
        }
        for day in [2, 5, 12] {
            fixture.interval(rower, duration: 360, intensity: 262, average: 164, on: .days(ago: day).addingTimeInterval(-60))
        }
        try fixture.save()

        let detail = fixture.ergDetailModel(for: rower)
        let model = try #require(detail.historySheet())

        #expect(detail.readout?.aside == "6:00 in Z4")
        #expect(detail.readout?.heartRate == "164 bpm")
        #expect(detail.readout?.entryCount == 12)
        #expect(model.rows.count == 12)
        #expect(model.older.count == 3)
    }

    @Test("A point's rows read date · intensity with the pace beside a speed · avg/peak bpm")
    func aRowReadsTheEntry() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", unit: .speed, kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 15.0, incline: 1, average: 164, peak: 170, on: .days(ago: 1))
        try fixture.save()

        let model = try #require(fixture.ergDetailModel(for: treadmill).historySheet())

        #expect(model.title == "6:00 in Z4 · 1 %")
        #expect(model.rows.map(\.text.decimalPoint) == ["yesterday · 15.0 km/h (4:00 /km) · 164/170 bpm"])
    }

    @Test("The point's sheet is scoped to the screen's machine")
    func thePointIsScopedToTheMachine() throws {
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
        let model = try #require(detail.historySheet())

        #expect(model.rows.map(\.intensity.decimalPoint) == ["15.0 km/h (4:00 /km)"])
    }

    // MARK: - The over-20:00 list

    @Test("The over-20:00 caption opens one flat list, newest first, with the duration on every row")
    func theOverTheAxisList() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 360, intensity: 260, average: 164, on: .days(ago: 1))
        fixture.interval(rower, duration: 1500, intensity: 220, average: 164, peak: 171, on: .days(ago: 20))
        fixture.interval(rower, duration: 1320, intensity: 230, average: 165, peak: 172, on: .days(ago: 3))
        // Over 20:00, but another zone's.
        fixture.interval(rower, duration: 1800, intensity: 200, average: 150, on: .days(ago: 2))
        try fixture.save()

        let detail = fixture.ergDetailModel(for: rower)
        #expect(detail.overTheAxisCaption == "2 entries over 20:00")
        let model = try #require(detail.overTheAxisSheet())

        let twentyDaysAgo = RelativeDay.text(for: .days(ago: 20), asOf: .now)
        #expect(model.title == "Over 20:00 in Z4")
        #expect(model.rows.map(\.text) == [
            "3 days ago · 22:00 · 230 W · 165/172 bpm",
            "\(twentyDaysAgo) · 25:00 · 220 W · 164/171 bpm",
        ])
        #expect(model.older.isEmpty)
    }

    @Test("A zone with no caption has no over-20:00 list to open")
    func noCaptionNoList() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 360, intensity: 260, average: 164)
        try fixture.save()

        #expect(fixture.ergDetailModel(for: rower).overTheAxisSheet() == nil)
    }

    // MARK: - The zones gate

    @Test("Without zones there is no door; entries logged then are reached once zones are set")
    func noZonesNoDoor() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 360, intensity: 260, average: 164)
        fixture.interval(rower, duration: 1500, intensity: 220, average: 164)
        try fixture.save()
        let detail = fixture.ergDetailModel(for: rower)

        #expect(detail.historySheet() == nil)
        #expect(detail.overTheAxisSheet() == nil)

        fixture.zones(117, 140, 158, 170)
        detail.refresh()

        #expect(detail.historySheet()?.rows.count == 1)
        #expect(detail.overTheAxisSheet()?.rows.count == 1)
    }

    // MARK: - Edit

    @Test("An edit that moves an entry to another zone or duration makes its row vanish")
    func anEditMovesTheRowOut() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 360, intensity: 262, average: 164, peak: 170, on: .days(ago: 2))
        fixture.interval(rower, duration: 360, intensity: 260, average: 164, peak: 170, on: .days(ago: 1))
        try fixture.save()
        let detail = fixture.ergDetailModel(for: rower)
        let model = try #require(detail.historySheet())

        // A heart rate retyped into Z3.
        let newest = try #require(model.rows.first)
        let zone = try #require(model.editSheet(for: newest))
        zone.fill(0, "", "", "150", "160")
        zone.save()

        #expect(model.rows.map(\.intensity) == ["262 W"])
        #expect(detail.readout?.aside == "6:00 in Z4")
        #expect(detail.readout?.heartRate == "164 bpm")
        #expect(detail.readout?.entryCount == 1)
        #expect(detail.hasLine(3))

        // A duration retyped: 6:02 is a point of its own.
        let last = try #require(model.rows.first)
        let duration = try #require(model.editSheet(for: last))
        duration.fill(0, "602")
        duration.save()

        #expect(model.isEmpty)
        #expect(detail.selection?.duration == 362)
    }

    // MARK: - Delete

    @Test("Deleting an entry inside the window pulls an older visit above the divider")
    func aDeletePullsAnOlderVisitUp() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        for day in 1...11 {
            fixture.interval(rower, duration: 360, intensity: Double(250 + day), average: 164, on: .days(ago: day))
        }
        try fixture.save()
        let detail = fixture.ergDetailModel(for: rower)
        let model = try #require(detail.historySheet())
        #expect(model.older.map(\.intensity) == ["261 W"])

        model.delete(model.rows[3])

        #expect(model.rows.map(\.intensity) == ["251 W", "252 W", "253 W", "255 W", "256 W", "257 W", "258 W", "259 W", "260 W", "261 W"])
        #expect(model.older.isEmpty)
        // Behind the sheet, the readout has re-read: the same ten entries.
        #expect(detail.readout?.aside == "6:00 in Z4")
        #expect(detail.readout?.heartRate == "164 bpm")
        #expect(detail.readout?.entryCount == 10)
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).count == 10)
    }

    // MARK: - The emptied point

    @Test("Deleting a point's last entry leaves the sheet open and empty, and the selection falls to the nearest duration left")
    func anEmptiedPointFallsToTheNearestDuration() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 180, intensity: 280, average: 164, on: .days(ago: 3))
        fixture.interval(rower, duration: 720, intensity: 240, average: 164, on: .days(ago: 2))
        fixture.interval(rower, duration: 360, intensity: 260, average: 164, on: .days(ago: 1))
        try fixture.save()
        let detail = fixture.ergDetailModel(for: rower)
        let model = try #require(detail.historySheet())

        model.delete(try #require(model.rows.first))

        #expect(model.isEmpty)
        // 6:00 is gone: 3:00 and 12:00 are left, and the nearer is 3:00.
        #expect(detail.selection == .init(zone: 4, duration: 180, incline: 0))
        #expect(detail.readout?.intensity == "280 W")
    }

    @Test("An emptied zone dims, and an emptied scope is the empty state")
    func anEmptiedZoneDimsAndAnEmptiedScopeIsEmpty() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 360, intensity: 200, average: 150, on: .days(ago: 2))
        fixture.interval(rower, duration: 360, intensity: 260, average: 164, on: .days(ago: 1))
        try fixture.save()
        let detail = fixture.ergDetailModel(for: rower)
        let z4 = try #require(detail.historySheet())

        z4.delete(try #require(z4.rows.first))

        #expect(detail.selection?.zone == 4)
        #expect(detail.hasLine(4) == false)
        #expect(detail.readout == nil)

        detail.select(zone: 3)
        let z3 = try #require(detail.historySheet())
        z3.delete(try #require(z3.rows.first))

        #expect(z3.isEmpty)
        #expect(detail.isEmpty)
    }
}
