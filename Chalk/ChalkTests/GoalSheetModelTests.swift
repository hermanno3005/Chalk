import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The goal sheet (#74): the log sheet's two-stage number borrowed whole, with no
/// seeded weight, no machine caption and a live line in place of the verdict.
@Suite("Goal sheet model")
struct GoalSheetModelTests {

    // MARK: - Seeding

    @Test("Reps start at the rep count the detail screen is scrubbed to")
    func repsSeedFromTheSelection() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 100)
        let detail = fixture.detailModel(for: exercise)
        detail.select(3)

        let sheet = try #require(detail.goalSheet())

        #expect(sheet.number.reps == 3)
        #expect(sheet.number.stage == .reps)
    }

    @Test("Reps start at 5 on a screen with no readout")
    func repsFallBackToFive() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        let detail = fixture.detailModel(for: exercise)

        let sheet = try #require(detail.goalSheet())

        #expect(sheet.number.reps == 5)
    }

    @Test("The weight stage opens blank with the keypad up, even with history")
    func theWeightOpensBlank() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 100)
        let sheet = fixture.goalSheetModel(for: exercise, reps: 5)

        sheet.number.advance()

        #expect(sheet.number.weight == nil)
        #expect(sheet.number.numberText == "")
        #expect(sheet.number.mode == .keypad)
    }

    // MARK: - Set goal

    @Test("Set goal is enabled only for at least one rep and more than nothing")
    func setGoalEnablement() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        let sheet = fixture.goalSheetModel(for: exercise, reps: 5)

        sheet.number.advance()
        #expect(!sheet.canSetGoal)

        sheet.number.type(.digit(0))
        #expect(!sheet.canSetGoal)

        sheet.number.type(.delete)
        sheet.number.type(.digit(1))
        sheet.number.type(.digit(4))
        sheet.number.type(.digit(0))
        #expect(sheet.canSetGoal)

        sheet.number.backToReps()
        sheet.number.tapNumber()
        #expect(sheet.number.reps == nil)
        #expect(!sheet.canSetGoal)
    }

    @Test("No ceiling blocks a goal, however heavy or however many reps")
    func noCeiling() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        let sheet = fixture.goalSheetModel(for: exercise, reps: 30)

        sheet.number.advance()
        type(sheet, "400")

        #expect(sheet.canSetGoal)
    }

    // MARK: - The line

    @Test("A goal above your best says how far above")
    func theLineAboveYourBest() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 100)
        let sheet = fixture.goalSheetModel(for: exercise, reps: 5)

        sheet.number.advance()
        type(sheet, "140")

        #expect(sheet.line == .init(text: "40 kg above your 5-rep best", isReached: false))
    }

    @Test("A goal you have already lifted says so, and does not block Set goal")
    func theLineAlreadyReached() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 115)
        let sheet = fixture.goalSheetModel(for: exercise, reps: 5)

        sheet.number.advance()
        type(sheet, "110")
        #expect(sheet.line == .init(text: "Already reached — your 5-rep best is 115 kg", isReached: true))

        type(sheet, "115", fresh: true)
        #expect(sheet.line == .init(text: "Already reached — your 5-rep best is 115 kg", isReached: true))
        #expect(sheet.canSetGoal)
    }

    @Test("Higher-rep work counts toward the best a goal is compared with")
    func theLineReadsTheBackfilledBest() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 8, weight: 100)
        let sheet = fixture.goalSheetModel(for: exercise, reps: 5)

        sheet.number.advance()
        type(sheet, "120")

        #expect(sheet.line == .init(text: "20 kg above your 5-rep best", isReached: false))
    }

    @Test("With nothing reaching that rep count the line says it is a first")
    func theLineFirstGoal() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 3, weight: 120)
        let sheet = fixture.goalSheetModel(for: exercise, reps: 5)

        sheet.number.advance()
        type(sheet, "140")

        #expect(sheet.line == .init(text: "First goal at 5 reps", isReached: false))
    }

    @Test("The line is silent on the reps stage")
    func theLineIsSilentOnReps() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 100)
        let sheet = fixture.goalSheetModel(for: exercise, reps: 5)

        #expect(sheet.line == nil)
    }

    // MARK: - Setting and clearing

    @Test("Setting a goal replaces the old one and re-stamps when it was set")
    func settingReplacesAndRestamps() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        let longAgo = Date.days(ago: 30)
        GoalScope.exercise(exercise).set(reps: 3, weight: 120, at: longAgo)
        try fixture.save()
        var changed = 0
        let sheet = fixture.goalSheetModel(for: exercise, reps: 5) { changed += 1 }
        #expect(sheet.hasGoal)

        let before = Date.now
        sheet.number.advance()
        type(sheet, "140")
        sheet.setGoal()

        let reread = try #require(try fixture.afterRelaunch().fetch(FetchDescriptor<Exercise>()).first)
        #expect(reread.goalReps == 5)
        #expect(reread.goalWeight == 140)
        #expect(try #require(reread.goalSetAt) >= before)
        #expect(changed == 1)
    }

    @Test("Clearing a goal sets all three fields to nil")
    func clearingNilsAllThree() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        GoalScope.exercise(exercise).set(reps: 5, weight: 140)
        try fixture.save()
        var changed = 0
        let sheet = fixture.goalSheetModel(for: exercise, reps: 5) { changed += 1 }

        sheet.clearGoal()

        let reread = try #require(try fixture.afterRelaunch().fetch(FetchDescriptor<Exercise>()).first)
        #expect(reread.goalReps == nil)
        #expect(reread.goalWeight == nil)
        #expect(reread.goalSetAt == nil)
        #expect(changed == 1)
    }

    @Test("Clear goal is offered only where a goal exists")
    func clearIsOfferedOnlyWithAGoal() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")

        #expect(!fixture.goalSheetModel(for: exercise, reps: 5).hasGoal)
    }

    @Test("A gym-bound goal is set on the machine, not the exercise")
    func aGymBoundGoalLandsOnTheMachine() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let machine = fixture.machine(for: exercise, at: fixture.gym("Fitness X"))
        let sheet = fixture.goalSheetModel(for: exercise, on: machine, reps: 8)

        sheet.number.advance()
        type(sheet, "200")
        sheet.setGoal()

        #expect(machine.goalReps == 8)
        #expect(machine.goalWeight == 200)
        #expect(exercise.goalReps == nil)
        #expect(exercise.goalWeight == nil)
    }

    /// Types a whole number on the keypad — whole, so the test reads the same in any
    /// locale's decimal separator.
    private func type(_ sheet: GoalSheetModel, _ digits: String, fresh: Bool = false) {
        if fresh {
            sheet.number.tapNumber()
            sheet.number.tapNumber()
        }
        for digit in digits {
            sheet.number.type(.digit(Int(String(digit))!))
        }
    }
}
