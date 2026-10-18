import Foundation
import SwiftData
import Testing

@testable import Chalk

/// A zone with no line on the erg detail screen (SPEC §13.8): text where the chart would
/// be, and up to two lines quoting the nearest zone above and below that has one.
///
/// The rules an implementer gets subtly wrong: **the quote is read at the duration closest
/// to the selection**, which stays where it was when you tap into a zone with no line,
/// and **quotes come from on-axis points only** — a zone whose entries are all over
/// 20:00 has no line to quote.
@Suite("Erg zone with no line")
struct ErgNoLineTests {

    @Test("A zone with no line says so, with the heart rates nothing here averaged")
    func theNoLineText() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        let machine = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        fixture.interval(treadmill, machine: machine, duration: 180, intensity: 16.5, average: 175)
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        #expect(model.noLine == nil)

        model.select(zone: 4)

        let noLine = try #require(model.noLine)
        #expect(noLine.title == "No Z4 on this machine yet.")
        #expect(noLine.detail == "Nothing you've logged here averaged 158–169 bpm.")
    }

    // MARK: - Quotes

    @Test("A first visit that only reached Z5 quotes Z5 as too hard")
    func aQuoteFromAbove() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 180, intensity: 16.5, average: 175)
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        model.select(zone: 4)

        let noLine = try #require(model.noLine)
        #expect(noLine.title == "No Z4 on this erg yet.")
        #expect(noLine.quotes.map(\.text.decimalPoint) == ["Z5 3:00 at 16.5 km/h — too hard"])
    }

    @Test("A zone below with a line is quoted as too easy")
    func aQuoteFromBelow() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 600, intensity: 13.5, average: 150)
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        model.select(zone: 4)

        let noLine = try #require(model.noLine)
        #expect(noLine.quotes.map(\.text.decimalPoint) == ["Z3 10:00 at 13.5 km/h — too easy"])
    }

    @Test("Above and below, each the nearest zone with a line, the harder first")
    func quotesFromBothSides() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 180, intensity: 16.5, average: 175, on: .days(ago: 3))
        fixture.interval(treadmill, duration: 600, intensity: 11.0, average: 130, on: .days(ago: 2))
        fixture.interval(treadmill, duration: 600, intensity: 13.5, average: 150, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        model.select(zone: 4)

        // Z3 is nearer than Z2, so Z2 says nothing.
        let noLine = try #require(model.noLine)
        #expect(noLine.quotes.map(\.text.decimalPoint) == [
            "Z5 3:00 at 16.5 km/h — too hard",
            "Z3 10:00 at 13.5 km/h — too easy",
        ])
    }

    @Test("A zone with no line here and none either side quotes nothing")
    func nothingToQuote() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 600, intensity: 11.0, average: 130)
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        model.select(zone: 1)

        let noLine = try #require(model.noLine)
        #expect(noLine.detail == "Nothing you've logged here averaged below 117 bpm.")
        #expect(noLine.quotes.map(\.text.decimalPoint) == ["Z2 10:00 at 11.0 km/h — too hard"])

        model.select(zone: 5)
        #expect(model.noLine?.detail == "Nothing you've logged here averaged 170+ bpm.")
        #expect(model.noLine?.quotes.map(\.text.decimalPoint) == ["Z2 10:00 at 11.0 km/h — too easy"])
    }

    @Test("A quote reads the neighbour's duration closest to the selected one")
    func theClosestDuration() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 60, intensity: 18.5, average: 175, on: .days(ago: 4))
        fixture.interval(treadmill, duration: 240, intensity: 16.6, average: 175, on: .days(ago: 4))
        fixture.interval(treadmill, duration: 600, intensity: 15.8, average: 175, on: .days(ago: 4))
        fixture.interval(treadmill, duration: 600, intensity: 13.5, average: 150, on: .days(ago: 2))
        fixture.interval(treadmill, duration: 360, intensity: 14.0, average: 150, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        model.select(zone: 4)
        // 6:00 is nearer 4:00 than 10:00.
        #expect(model.noLine?.quotes.first?.text.decimalPoint == "Z5 4:00 at 16.6 km/h — too hard")

        model.select(zone: 3)
        model.select(duration: 600)
        model.select(zone: 4)
        #expect(model.noLine?.quotes.map(\.text.decimalPoint) == [
            "Z5 10:00 at 15.8 km/h — too hard",
            "Z3 10:00 at 13.5 km/h — too easy",
        ])
    }

    @Test("Quotes come from on-axis points only")
    func quotesAreOnTheAxis() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 1500, intensity: 14.0, average: 175, on: .days(ago: 3))
        fixture.interval(treadmill, duration: 1200, intensity: 12.5, average: 150, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        model.select(zone: 4)

        // Z5's only entry is 25:00: stored, not drawn, so Z5 has no line to quote.
        #expect(model.noLine?.quotes.map(\.text.decimalPoint) == ["Z3 20:00 at 12.5 km/h — too easy"])

        fixture.interval(treadmill, duration: 180, intensity: 16.5, average: 175, on: .days(ago: 2))
        try fixture.save()
        model.refresh()

        // 25:00 is nearer 20:00 than 3:00 is, and still never quoted.
        #expect(model.noLine?.quotes.map(\.text.decimalPoint) == [
            "Z5 3:00 at 16.5 km/h — too hard",
            "Z3 20:00 at 12.5 km/h — too easy",
        ])
    }

    @Test("A zone whose only entries are over 20:00 has no line, and keeps its caption")
    func anOverTwentyOnlyZone() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts, kind: .freeWeight)
        fixture.interval(rower, duration: 360, intensity: 260, average: 164, on: .days(ago: 2))
        fixture.interval(rower, duration: 1800, intensity: 180, average: 150, on: .days(ago: 1))
        try fixture.save()

        let model = fixture.ergDetailModel(for: rower)

        // Opens on the 30:00 in Z3, which has no point.
        let noLine = try #require(model.noLine)
        #expect(noLine.title == "No Z3 on this erg yet.")
        #expect(noLine.detail == "Nothing you've logged here averaged 140–157 bpm.")
        #expect(noLine.quotes.map(\.text) == ["Z4 6:00 at 260 W — too hard"])
        #expect(model.overTheAxisCaption == "1 entry over 20:00")
    }
}
