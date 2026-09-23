import Testing

@testable import Chalk

/// The two-stage giant number on its own (SPEC §6.1–6.2): reps, then weight, with
/// steppers for nudges and a keypad for jumps. No store, no exercise — what it means is
/// the sheet's business, and the log sheet and the goal sheet each bring their own.
@Suite("Two-stage number")
struct TwoStageNumberTests {

    // MARK: - Staging

    @Test("It opens on reps with the steppers, showing the seed")
    func opensOnReps() {
        let number = TwoStageNumber(reps: 8, weight: 62.5)

        #expect(number.stage == .reps)
        #expect(number.mode == .steppers)
        #expect(number.numberText == "8")
        #expect(number.unitText == "reps")
    }

    @Test("Advancing shows the weight, and going back shows the reps")
    func advancesAndReturns() {
        var number = TwoStageNumber(reps: 8, weight: 62.5)

        number.advance()
        #expect(number.stage == .weight)
        #expect(number.mode == .steppers)
        #expect(number.numberText == kg(62.5))
        #expect(number.unitText == "kg")
        #expect(number.repsLabel == "8 reps")

        number.backToReps()
        #expect(number.stage == .reps)
        #expect(number.reps == 8)
    }

    @Test("A blank weight opens with the keypad up")
    func aBlankWeightOpensOnTheKeypad() {
        var number = TwoStageNumber(reps: 5, weight: nil)

        number.advance()
        #expect(number.mode == .keypad)
        #expect(number.numberText == "")

        number.backToReps()
        #expect(number.mode == .steppers)
    }

    @Test("There is no advancing without a rep count")
    func noAdvanceWithoutReps() {
        var number = TwoStageNumber(reps: nil, weight: 60)

        #expect(number.canAdvance == false)
        number.advance()
        #expect(number.stage == .reps)
    }

    @Test("One rep is not phrased as many")
    func oneRepInflects() {
        var number = TwoStageNumber(reps: 1, weight: 60)
        #expect(number.unitText == "rep")
        number.advance()
        #expect(number.repsLabel == "1 rep")
    }

    // MARK: - Steppers

    @Test("Reps step by one and clamp at one")
    func repsStepAndClamp() {
        var number = TwoStageNumber(reps: 3, weight: nil)

        number.step(+1)
        #expect(number.reps == 4)
        for _ in 0..<10 { number.step(-1) }
        #expect(number.reps == 1)
    }

    @Test("On-grid weight steps by 2.5")
    func onGridWeightSteps() {
        var number = TwoStageNumber(reps: 5, weight: 60)
        number.advance()

        number.step(+1)
        #expect(number.weight == 62.5)
        number.step(-1)
        number.step(-1)
        #expect(number.weight == 57.5)
    }

    @Test("Off-grid weight snaps to the next multiple in the direction tapped")
    func offGridWeightSnaps() {
        var up = TwoStageNumber(reps: 5, weight: 57)
        up.advance()
        up.step(+1)
        #expect(up.weight == 57.5)
        up.step(+1)
        #expect(up.weight == 60)

        var down = TwoStageNumber(reps: 5, weight: 57)
        down.advance()
        down.step(-1)
        #expect(down.weight == 55)
        down.step(-1)
        #expect(down.weight == 52.5)
    }

    @Test("Weight clamps at zero, and a blank weight steps from zero")
    func weightClampsAtZero() {
        var number = TwoStageNumber(reps: 5, weight: 1)
        number.advance()

        number.step(-1)
        #expect(number.weight == 0)
        number.step(-1)
        #expect(number.weight == 0)
        #expect(number.numberText == "0")

        var blank = TwoStageNumber(reps: 5, weight: nil)
        blank.advance()
        blank.tapNumber()
        blank.step(+1)
        #expect(blank.weight == 2.5)
    }

    // MARK: - The keypad

    @Test("Tapping the number opens a blank keypad, and tapping again keeps what was typed")
    func tappingTogglesTheKeypad() {
        var number = TwoStageNumber(reps: 5, weight: nil)

        number.tapNumber()
        #expect(number.mode == .keypad)
        #expect(number.reps == nil)
        #expect(number.numberText == "")

        number.type(.digit(1))
        number.type(.digit(2))
        #expect(number.reps == 12)

        number.tapNumber()
        #expect(number.mode == .steppers)
        #expect(number.reps == 12)
        #expect(number.numberText == "12")
    }

    @Test("Closing the keypad without typing puts the number back")
    func aStrayTapCostsNothing() {
        var number = TwoStageNumber(reps: 8, weight: 62.5)
        number.advance()

        number.tapNumber()
        #expect(number.weight == nil)
        number.tapNumber()

        #expect(number.mode == .steppers)
        #expect(number.weight == 62.5)
    }

    @Test("Typing brings the keypad up without tapping the number")
    func typingOpensTheKeypad() {
        var number = TwoStageNumber(reps: 5, weight: nil)

        number.type(.digit(8))
        #expect(number.mode == .keypad)
        #expect(number.reps == 8)
    }

    @Test("The typed value flows in as you type")
    func typedValueFlowsIn() {
        var number = TwoStageNumber(reps: 5, weight: nil)
        number.advance()

        number.type(.digit(6))
        #expect(number.weight == 6)
        number.type(.digit(2))
        #expect(number.weight == 62)
        number.type(.decimal)
        #expect(number.weight == 62)
        #expect(number.numberText == "62" + WeightText.decimalSeparator)
        number.type(.digit(5))
        #expect(number.weight == 62.5)
        #expect(number.numberText == kg(62.5))

        number.type(.delete)
        number.type(.delete)
        #expect(number.weight == 62)
        number.type(.delete)
        number.type(.delete)
        #expect(number.weight == nil)
        number.type(.delete)
        #expect(number.weight == nil)
    }

    @Test("A leading decimal reads as a fraction, and a second decimal is ignored")
    func decimalPoints() {
        var number = TwoStageNumber(reps: 5, weight: nil)
        number.advance()

        number.type(.decimal)
        number.type(.digit(5))
        number.type(.decimal)
        #expect(number.weight == 0.5)
    }

    @Test("A lone leading zero is replaced by the next digit")
    func leadingZeroIsAPlaceholder() {
        var number = TwoStageNumber(reps: 5, weight: nil)
        number.advance()

        number.type(.digit(0))
        #expect(number.weight == 0)
        number.type(.digit(7))
        #expect(number.numberText == "7")
    }

    @Test("The decimal key does nothing on the reps stage")
    func decimalIsDeadOnReps() {
        var number = TwoStageNumber(reps: 5, weight: nil)
        number.tapNumber()
        number.type(.digit(8))
        number.type(.decimal)
        number.type(.digit(5))

        #expect(number.numberText == "85")
        #expect(number.reps == 85)
    }

    @Test("A thumb held on a key stops at six characters")
    func typingStopsAtSixCharacters() {
        var number = TwoStageNumber(reps: 5, weight: nil)
        number.advance()
        for _ in 0..<12 { number.type(.digit(9)) }
        number.type(.decimal)

        #expect(number.weight == 999_999)
        #expect(number.numberText == "999999")
    }

    @Test("Changing stage closes the keypad and forgets what was typed")
    func stagingDropsTheDraft() {
        var number = TwoStageNumber(reps: 5, weight: nil)
        number.tapNumber()
        number.type(.digit(6))
        number.advance()
        number.type(.digit(4))
        number.type(.digit(0))

        number.backToReps()
        #expect(number.mode == .steppers)
        #expect(number.numberText == "6")
        number.advance()
        #expect(number.mode == .steppers)
        #expect(number.numberText == "40")
    }

    // MARK: - Seeding a weight from outside

    @Test("A weight seeded on the weight stage reopens it over the new value")
    func seedingOnTheWeightStage() {
        var number = TwoStageNumber(reps: 5, weight: 60)
        number.advance()
        number.tapNumber()
        number.type(.digit(7))

        number.seedWeight(nil)
        #expect(number.weight == nil)
        #expect(number.mode == .keypad)
        #expect(number.numberText == "")

        number.seedWeight(80)
        #expect(number.mode == .steppers)
        #expect(number.numberText == "80")
    }

    @Test("A weight seeded on the reps stage waits for the weight stage")
    func seedingOnTheRepsStage() {
        var number = TwoStageNumber(reps: 5, weight: 60)

        number.seedWeight(nil)
        #expect(number.stage == .reps)
        #expect(number.numberText == "5")

        number.advance()
        #expect(number.mode == .keypad)
    }
}

private func kg(_ weight: Double) -> String {
    weight.kilogramsText
}
