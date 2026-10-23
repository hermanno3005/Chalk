import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The weight unit (SPEC §15.2, ADR-0009): every strength weight and goal is a plain
/// number on the scale chosen now, and every surface that writes one writes that scale.
/// Nothing converts at read time, so a library on lb shows the very numbers it stores.
@Suite("Weight unit")
struct WeightUnitTests {

    // MARK: - The phone's update

    @Test("A launch with no unit stored, over a library that isn't empty, stores kg", arguments: [
        "an exercise", "an erg", "a gym",
    ])
    func aLaunchOverALibraryStoresKilograms(holding row: String) throws {
        let fixture = try LibraryFixture()
        switch row {
        case "an exercise": fixture.exercise("Squat")
        case "an erg": fixture.erg("Rower", unit: .split)
        default: fixture.gym("Fitness X")
        }
        try fixture.save()

        _ = fixture.libraryModel()

        #expect(WeightUnit.stored(in: fixture.defaults) == .kg)
    }

    @Test("A launch over an empty library, seeded groups and all, leaves the unit unset")
    func aLaunchOverAnEmptyLibraryLeavesTheUnitUnset() throws {
        let fixture = try LibraryFixture()

        let model = fixture.libraryModel()

        #expect(try !fixture.allGroups().isEmpty)
        #expect(WeightUnit.stored(in: fixture.defaults) == nil)
        // Unset reads as kg until onboarding picks one.
        model.create(name: "Squat", kind: .freeWeight)
        #expect(WeightUnit(defaults: fixture.defaults) == .kg)
    }

    @Test("A launch never touches a unit already stored")
    func aLaunchKeepsAStoredUnit() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.lb)
        fixture.exercise("Squat")
        try fixture.save()

        _ = fixture.libraryModel()

        #expect(WeightUnit.stored(in: fixture.defaults) == .lb)
    }

    // MARK: - The library

    @Test("On lb, the tile and the resume card write pounds")
    func theLibraryWritesPounds() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.lb)
        let squat = fixture.exercise("Squat")
        fixture.log(squat, reps: 5, weight: 225)
        try fixture.save()

        let model = fixture.libraryModel()

        #expect(model.resume?.text() == "5 × 225 lb · today")
        guard case .grid(let sections) = model.content else {
            Issue.record("Expected the grid")
            return
        }
        #expect(sections[0].tiles[0].subtitle() == "5 × 225 lb · today")
    }

    @Test("On lb, endurance's tile and resume card are unchanged: an erg has no weight to write")
    func enduranceIsUntouched() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        fixture.interval(rower, duration: 1_200, intensity: 118)
        try fixture.save()
        let onKilograms = fixture.libraryModel()
        onKilograms.show(.endurance)
        let card = try #require(onKilograms.resume?.text())

        fixture.weightUnit(.lb)
        let onPounds = fixture.libraryModel()

        #expect(onPounds.resume?.text() == card)
        #expect(!card.contains("kg") && !card.contains("lb"))
    }

    // MARK: - The detail screen

    @Test("On lb, the readout and the goal line write pounds")
    func theDetailScreenWritesPounds() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.lb)
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 185, on: .days(ago: 1))
        GoalScope.exercise(bench).set(reps: 5, weight: 225, at: .days(ago: 2))

        let model = fixture.libraryModel().detail(for: bench)

        #expect(model.readout?.weightWithUnit == "185 lb")
        #expect(model.goalLine?.text == "Goal 225 × 5 · 40 lb to go")
    }

    @Test("On lb, the machine hint writes pounds, on the detail screen and in the log sheet")
    func theMachineHintWritesPounds() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.lb)
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: legPress, at: gym, label: "By the window")
        let sibling = fixture.machine(for: legPress, at: gym, manufacturer: "Hammer Strength")
        fixture.log(sibling, reps: 5, weight: 315, on: .days(ago: 2))

        let model = fixture.libraryModel().detail(for: legPress)
        model.select(here)
        let sheet = model.logSheet {}
        sheet.advance()

        #expect(model.hint?.emptyStateLine == "No entries here — 315 lb × 5 on Hammer Strength")
        #expect(sheet.verdict?.text == "No history here — 315 lb × 5 on Hammer Strength")
    }

    // MARK: - The sheets

    @Test("On lb, the log sheet writes its weight and its verdicts in pounds")
    func theLogSheetWritesPounds() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.lb)
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 185, on: .days(ago: 1))

        let sheet = fixture.libraryModel().logSheet(for: bench)
        sheet.advance()
        #expect(sheet.unitText == "lb")
        #expect(sheet.verdict?.text == "Matches your 5-rep best")

        sheet.step(+1)
        #expect(sheet.weight == 190)
        #expect(sheet.verdict?.text == "Beats your 5-rep best by 5 lb")

        sheet.step(-1)
        sheet.step(-1)
        #expect(sheet.verdict?.text == "Your 5-rep best is 185 lb")
    }

    @Test("On lb, the goal sheet steps on the 5 lb grid and writes its line in pounds")
    func theGoalSheetWritesPounds() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.lb)
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 185, on: .days(ago: 1))

        let sheet = try #require(fixture.libraryModel().detail(for: bench).goalSheet())
        sheet.number.advance()
        sheet.number.type(.digit(2))
        sheet.number.type(.digit(2))
        sheet.number.type(.digit(2))
        sheet.number.tapNumber()
        sheet.number.step(+1)

        #expect(sheet.number.weight == 225)
        #expect(sheet.line?.text == "40 lb above your 5-rep best")

        for _ in 0..<9 { sheet.number.step(-1) }
        #expect(sheet.line?.text == "Already reached — your 5-rep best is 185 lb")
    }

    @Test("On lb, the history sheet's rows write pounds")
    func theHistorySheetWritesPounds() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.lb)
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 185, on: .days(ago: 1))

        let history = try #require(fixture.libraryModel().detail(for: bench).historySheet())

        #expect(history.rows.map(\.lift) == ["5 × 185 lb"])
    }
}
