import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The two-stage log sheet, free-weight (SPEC §6.1–6.3, §6.5, §6.7).
///
/// The two an implementer gets wrong: **weight stepping snaps to the 2.5 kg grid**
/// rather than adding 2.5, and the **cold start never guesses a weight** — it opens
/// blank with the keypad up rather than filling in a number nobody lifted.
@Suite("Log sheet model")
struct LogSheetModelTests {

    // MARK: - Seeding

    @Test("Both stages seed from the most recent entry")
    func seedsFromTheMostRecentEntry() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 80, on: .days(ago: 9))
        fixture.log(exercise, reps: 8, weight: 62.5, on: .days(ago: 2))
        fixture.log(exercise, reps: 3, weight: 90, on: .days(ago: 30))

        let model = fixture.logSheetModel(for: exercise)

        #expect(model.reps == 8)
        #expect(model.numberText == "8")
        model.advance()
        #expect(model.weight == 62.5)
        #expect(model.numberText == kg(62.5))
        #expect(model.mode == .steppers)
    }

    @Test("A cold start is 5 reps and a blank weight with the keypad up")
    func coldStartLeavesTheWeightBlank() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")

        let model = fixture.logSheetModel(for: exercise)

        #expect(model.reps == 5)
        #expect(model.mode == .steppers)

        model.advance()
        // No arbitrary 20 kg: the app never seeds a load it cannot back up.
        #expect(model.weight == nil)
        #expect(model.numberText == "")
        #expect(model.mode == .keypad)
        #expect(model.canSave == false)
    }

    @Test("An unchanged repeat is two taps: Next, Save")
    func anUnchangedRepeatIsTwoTaps() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 8, weight: 62.5, on: .days(ago: 2))
        try fixture.save()

        let model = fixture.logSheetModel(for: exercise)
        #expect(model.canAdvance)
        model.advance()
        #expect(model.canSave)
        model.save()

        let logged = try fixture.afterRelaunch()
            .fetch(FetchDescriptor<Entry>())
            .map { [Double($0.reps), $0.weight] }
        #expect(logged == [[8, 62.5], [8, 62.5]])
    }

    // MARK: - Steppers

    @Test("Reps step by one and clamp at one")
    func repsStepByOneAndClampAtOne() throws {
        let model = try coldModel()

        model.step(+1)
        #expect(model.reps == 6)
        for _ in 0..<10 { model.step(-1) }
        #expect(model.reps == 1)
    }

    @Test("Weight stepping snaps to the 2.5 kg grid rather than adding 2.5")
    func weightSteppingSnapsToTheGrid() throws {
        let model = try coldModel()
        model.advance()
        model.type(.digit(5))
        model.type(.digit(7))
        model.tapNumber()

        model.step(+1)
        #expect(model.weight == 57.5)
        model.step(+1)
        #expect(model.weight == 60)
        model.step(-1)
        #expect(model.weight == 57.5)
    }

    @Test("Stepping down from an off-grid weight lands on the multiple below")
    func steppingDownFromOffGridLandsBelow() throws {
        let model = try coldModel()
        model.advance()
        model.type(.digit(5))
        model.type(.digit(7))

        model.tapNumber()
        model.step(-1)
        #expect(model.weight == 55)
        model.step(-1)
        #expect(model.weight == 52.5)
    }

    @Test("Weight clamps at zero, which is displayable but not savable")
    func weightClampsAtZero() throws {
        let model = try coldModel()
        model.advance()
        model.tapNumber()

        model.step(-1)
        #expect(model.weight == 0)
        #expect(model.numberText == "0")
        #expect(model.canSave == false)

        model.step(+1)
        #expect(model.weight == 2.5)
        #expect(model.canSave)
    }

    // MARK: - The keypad

    @Test("Tapping the number opens the keypad and tapping it again returns to the steppers")
    func tappingTheNumberTogglesTheKeypad() throws {
        let model = try coldModel()

        model.tapNumber()
        #expect(model.mode == .keypad)
        model.type(.digit(1))
        model.type(.digit(2))
        #expect(model.reps == 12)

        model.tapNumber()
        #expect(model.mode == .steppers)
        #expect(model.numberText == "12")
        model.step(+1)
        #expect(model.reps == 13)
    }

    @Test("Closing the keypad without typing puts the seed back")
    func aStrayTapOnTheNumberCostsNothing() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 8, weight: 62.5)

        let model = fixture.logSheetModel(for: exercise)
        model.advance()

        model.tapNumber()
        #expect(model.weight == nil)
        model.tapNumber()

        // A stray tap is not an edit: the two-tap log survives it.
        #expect(model.mode == .steppers)
        #expect(model.weight == 62.5)
        #expect(model.canSave)
    }

    @Test("The typed value flows in as you type")
    func typedValueFlowsInLive() throws {
        let model = try coldModel()
        model.advance()

        model.type(.digit(6))
        #expect(model.weight == 6)
        model.type(.digit(2))
        #expect(model.weight == 62)
        model.type(.decimal)
        model.type(.digit(5))
        #expect(model.weight == 62.5)
        #expect(model.numberText == kg(62.5))

        model.type(.delete)
        model.type(.delete)
        #expect(model.weight == 62)
        #expect(model.numberText == "62")
    }

    @Test("The decimal key is dead on the reps stage")
    func decimalIsDeadOnTheRepsStage() throws {
        let model = try coldModel()
        model.tapNumber()
        model.type(.digit(8))
        model.type(.decimal)
        model.type(.digit(5))

        #expect(model.numberText == "85")
        #expect(model.reps == 85)
    }

    @Test("Clearing the keypad leaves nothing to advance or save with")
    func clearingTheKeypadDisablesTheAction() throws {
        let model = try coldModel()
        model.tapNumber()
        model.type(.delete)

        #expect(model.reps == nil)
        #expect(model.numberText == "")
        #expect(model.canAdvance == false)
    }

    // MARK: - Staging

    @Test("The stage-two header carries the reps back to stage one")
    func theHeaderReturnsToStageOne() throws {
        let model = try coldModel()
        model.step(+1)
        model.advance()

        #expect(model.stage == .weight)
        #expect(model.repsLabel == "6 reps")

        model.backToReps()
        #expect(model.stage == .reps)
        #expect(model.mode == .steppers)
        #expect(model.reps == 6)
    }

    @Test("One rep is not phrased as many")
    func repsLabelInflects() throws {
        let model = try coldModel()
        for _ in 0..<4 { model.step(-1) }
        model.advance()

        #expect(model.repsLabel == "1 rep")
    }

    // MARK: - The verdict line

    @Test("Stage one stays silent")
    func stageOneHasNoVerdict() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 55)

        let model = fixture.logSheetModel(for: exercise)

        #expect(model.verdict == nil)
        model.advance()
        #expect(model.verdict != nil)
    }

    @Test("A weight above the rep-max beats it, by how much")
    func beatsTheRepMax() throws {
        let model = try verdictModel(best: 55, atReps: 5)
        model.advance()
        model.tapNumber()
        model.type(.digit(5))
        model.type(.digit(7))
        model.type(.decimal)
        model.type(.digit(5))

        #expect(model.verdict == .measured("Beats your 5-rep best by \(kg(2.5)) kg"))
    }

    @Test("A weight equal to the rep-max matches it")
    func matchesTheRepMax() throws {
        let model = try verdictModel(best: 55, atReps: 5)
        model.advance()

        #expect(model.verdict == .measured("Matches your 5-rep best"))
    }

    @Test("A weight below the rep-max is told what the rep-max is")
    func belowTheRepMax() throws {
        let model = try verdictModel(best: 55, atReps: 5)
        model.advance()
        model.tapNumber()
        model.type(.digit(5))
        model.type(.digit(0))

        #expect(model.verdict == .measured("Your 5-rep best is \(kg(55)) kg"))
    }

    @Test("A rep count with nothing behind it is a first entry")
    func firstEntryAtThisRepCount() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        // Triples only: monotonic backfill floors 1 through 3 and nothing above.
        fixture.log(exercise, reps: 3, weight: 100)

        let model = fixture.logSheetModel(for: exercise)
        model.tapNumber()
        model.type(.digit(8))
        model.advance()
        model.type(.digit(6))
        model.type(.digit(0))

        #expect(model.verdict == .measured("First entry at 8 reps"))
    }

    @Test("The verdict follows the backfill past the drawn axis")
    func verdictHoldsBeyondTheAxis() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 20, weight: 40)

        let model = fixture.logSheetModel(for: exercise)
        model.tapNumber()
        model.type(.digit(1))
        model.type(.digit(5))
        model.advance()
        model.tapNumber()
        model.type(.digit(4))
        model.type(.digit(0))

        #expect(model.verdict == .measured("Matches your 15-rep best"))
    }

    @Test("A blank weight is told the rep-max rather than judged against it")
    func aBlankWeightReadsTheRepMax() throws {
        let model = try verdictModel(best: 55, atReps: 5)
        model.advance()
        model.tapNumber()

        // Nothing is typed yet, so there is nothing to beat or match — the line spends
        // that moment saying what there is to beat.
        #expect(model.weight == nil)
        #expect(model.verdict == .measured("Your 5-rep best is \(kg(55)) kg"))
        #expect(model.canSave == false)
    }

    // MARK: - The fifth state: the machine hint

    @Test("A machine with no history quotes the sibling instead of saying nothing useful")
    func theFifthStateQuotesASibling() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(sibling, reps: 5, weight: 55, on: .days(ago: 2))

        let model = fixture.logSheetModel(for: exercise, on: here)
        model.advance()

        #expect(model.verdict == .hint("No history here — \(kg(55)) kg × 5 on Hammer Strength"))
        // A hint is not a verdict, and the line says so (SPEC §6.5).
        #expect(model.verdict?.isHint == true)
    }

    @Test("The hint never becomes a seed")
    func theHintSeedsNothing() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(sibling, reps: 5, weight: 55, on: .days(ago: 2))

        let model = fixture.logSheetModel(for: exercise, on: here)
        model.advance()

        // The weight stage opens blank with the keypad up, exactly as it does with no
        // hint at all: no number you have never lifted *here* is one tap from Save.
        #expect(model.weight == nil)
        #expect(model.mode == .keypad)
    }

    @Test("With no sibling to quote, the line stays on First entry")
    func withoutASiblingTheLineIsAFirstEntry() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")

        let model = fixture.logSheetModel(for: exercise, on: here)
        model.advance()

        #expect(model.verdict == .measured("First entry at 5 reps"))
    }

    @Test("A rep count the sibling cannot back up is a first entry, not a fallback")
    func theHintKeepsItsRepCount() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        // Triples only: the sibling has no best[5], so there is nothing to quote.
        fixture.log(sibling, reps: 3, weight: 100, on: .days(ago: 2))

        let model = fixture.logSheetModel(for: exercise, on: here)
        // The reps seed followed the sibling's triple, as rep counts do (SPEC §6.3) —
        // the hint's own rep count is the one being tested, so put it back on 5.
        model.tapNumber()
        model.type(.digit(5))
        model.advance()

        #expect(model.verdict == .measured("First entry at 5 reps"))
    }

    @Test("Correcting the machine moves the hint with the scope")
    func correctingTheMachineMovesTheHint() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let logged = fixture.machine(for: exercise, at: gym, label: "By the window")
        let fresh = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(logged, reps: 5, weight: 55, on: .days(ago: 2))

        let model = fixture.logSheetModel(for: exercise, on: logged)
        model.advance()
        #expect(model.verdict == .measured("Matches your 5-rep best"))

        model.select(fresh)

        // The screen behind the caption moved, so the line did too: nothing is proven
        // on the machine now in scope, and the one that is gets quoted.
        #expect(model.verdict == .hint("No history here — \(kg(55)) kg × 5 on By the window"))
    }

    @Test("Correcting the only entry on a machine leaves nothing here to speak for it")
    func editingTheOnlyEntryHereFallsBackToTheHint() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(here, reps: 5, weight: 40, on: .days(ago: 1))
        fixture.log(sibling, reps: 5, weight: 55, on: .days(ago: 2))
        let correcting = try #require(here.entries?.first)

        let model = fixture.logSheetModel(for: exercise, on: here, editing: correcting)
        model.advance()

        // An entry is not part of its own verdict (SPEC §6.5), and the hint reads the
        // same scope the verdict does — so the machine behind this sheet has nothing
        // else on it to compare against.
        #expect(model.verdict == .hint("No history here — \(kg(55)) kg × 5 on Hammer Strength"))
    }

    @Test("A free-weight sheet never hints")
    func aFreeWeightSheetNeverHints() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")

        let model = fixture.logSheetModel(for: exercise)
        model.advance()

        #expect(model.verdict == .measured("First entry at 5 reps"))
    }

    @Test("The hint holds at any rep count, quoting the sibling's best[5] as it is")
    func theHintHoldsAtAnyRepCount() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(sibling, reps: 5, weight: 55, on: .days(ago: 2))

        let model = fixture.logSheetModel(for: exercise, on: here)
        model.tapNumber()
        model.type(.digit(8))
        model.advance()

        // The sentence keeps its own fixed rep count — it is a lookup, not a verdict
        // about the eight you are about to do.
        #expect(model.verdict == .hint("No history here — \(kg(55)) kg × 5 on Hammer Strength"))
    }

    // MARK: - Commit

    @Test("Save is disabled at zero and enabled at any positive weight")
    func saveGuardsRepsAndWeight() throws {
        let model = try coldModel()
        model.advance()
        model.type(.digit(0))
        #expect(model.weight == 0)
        #expect(model.canSave == false)

        model.type(.decimal)
        model.type(.digit(5))
        #expect(model.weight == 0.5)
        #expect(model.canSave)
    }

    @Test("A saved entry moves the curve behind the sheet")
    func savingMovesTheCurve() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: 5, weight: 55)
        let detail = fixture.detailModel(for: exercise)
        #expect(detail.readout?.weight == 55)

        let model = fixture.logSheetModel(for: exercise, onSave: detail.refresh)
        model.advance()
        model.tapNumber()
        model.type(.digit(6))
        model.type(.digit(0))
        model.save()

        #expect(detail.readout?.weight == 60)
        #expect(detail.readout?.entriesBehind == 2)

        let reopened = try fixture.afterRelaunch()
        #expect(try reopened.fetch(FetchDescriptor<Entry>()).count == 2)
    }

    @Test("An unsavable sheet writes nothing")
    func anUnsavableSheetWritesNothing() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        try fixture.save()

        let model = fixture.logSheetModel(for: exercise)
        model.advance()
        model.save()

        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).isEmpty)
    }

    @Test("A thumb held on a key does not become a number")
    func theKeypadStopsAcceptingDigits() throws {
        let model = try coldModel()
        model.advance()
        for _ in 0..<12 { model.type(.digit(9)) }

        // Not a ceiling on a lift — there is no upper bound (SPEC §6.7) — just the
        // point past which the digits are a slip rather than a weight.
        #expect(model.weight == 999_999)
        #expect(model.canSave)
    }

    // MARK: - Helpers

    /// A sheet over an exercise with nothing logged: 5 reps, blank weight.
    private func coldModel() throws -> LogSheetModel {
        let fixture = try LibraryFixture()
        return fixture.logSheetModel(for: fixture.exercise("Bench Press"))
    }

    /// A sheet seeded from one entry, so the weight stage opens on `best[atReps]`.
    private func verdictModel(best: Double, atReps reps: Int) throws -> LogSheetModel {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Bench Press")
        fixture.log(exercise, reps: reps, weight: best)
        return fixture.logSheetModel(for: exercise)
    }
}

/// A weight as this device would write it — the tests assert the sheet's phrasing, not
/// the decimal separator of whichever locale they happen to run in.
private func kg(_ weight: Double) -> String {
    weight.kilogramsText
}
