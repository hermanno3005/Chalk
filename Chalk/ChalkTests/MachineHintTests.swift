import Foundation
import Testing

@testable import Chalk

/// The machine hint: your numbers for the same exercise on a *different* machine, shown
/// where the machine in front of you has none of its own (SPEC §5.4, §6.5).
///
/// One lookup behind both surfaces, and never part of a derivation — every test here
/// asserts a sentence, not a rep-max.
@Suite("Machine hint")
struct MachineHintTests {

    @Test("A free-weight exercise never hints")
    func freeWeightExercisesNeverHint() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Squat")

        #expect(MachineHint.lookUp(exercise, scopedTo: nil) == nil)
    }

    @Test("The sibling is the most recently used machine, whatever it weighs")
    func theSiblingIsTheMostRecentlyUsed() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let heavier = fixture.machine(for: exercise, at: gym, manufacturer: "Cybex")
        let recent = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(heavier, reps: 5, weight: 200, on: .days(ago: 30))
        fixture.log(recent, reps: 5, weight: 55, on: .days(ago: 2))

        let hint = try #require(MachineHint.lookUp(exercise, scopedTo: here))

        // The most recent one, not the best one: nothing in the spec ranks siblings
        // beyond `max(by:)` over the date.
        #expect(hint.text == "\(kg(55)) kg × 5 on Hammer Strength")
    }

    @Test("It quotes the sibling's best[5], backfill and all")
    func itQuotesTheSiblingsFiveRepMax() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        // A set of eights floors best[5] at the same weight, and is the heavier of the two.
        fixture.log(sibling, reps: 5, weight: 55, on: .days(ago: 4))
        fixture.log(sibling, reps: 8, weight: 60, on: .days(ago: 2))

        let hint = try #require(MachineHint.lookUp(exercise, scopedTo: here))

        #expect(hint.weight == 60)
        #expect(hint.text == "\(kg(60)) kg × 5 on Hammer Strength")
    }

    @Test("A sibling with no best[5] is silence, not a fallback rep count")
    func aSiblingWithoutAFiveRepMaxStaysSilent() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        // Triples only: the backfill floors 1 through 3 and leaves best[5] unproven.
        fixture.log(sibling, reps: 3, weight: 100, on: .days(ago: 2))

        #expect(MachineHint.lookUp(exercise, scopedTo: here) == nil)
    }

    @Test("The most recent sibling settles it — a quieter one is not tried instead")
    func aSilentSiblingIsNotSteppedOver() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let older = fixture.machine(for: exercise, at: gym, manufacturer: "Cybex")
        let recent = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(older, reps: 5, weight: 55, on: .days(ago: 30))
        fixture.log(recent, reps: 3, weight: 100, on: .days(ago: 2))

        // The screen shows one hint, never a list — and the one it would show has
        // nothing to say at 5 reps.
        #expect(MachineHint.lookUp(exercise, scopedTo: here) == nil)
    }

    @Test("A machine with history of its own is not hinted at")
    func aMachineWithHistoryGetsNoHint() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")
        fixture.log(here, reps: 3, weight: 80, on: .days(ago: 1))
        fixture.log(sibling, reps: 5, weight: 55, on: .days(ago: 2))

        #expect(MachineHint.lookUp(exercise, scopedTo: here) == nil)
    }

    @Test("No sibling, or none ever logged on, is silence")
    func nothingToQuoteIsSilence() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")

        #expect(MachineHint.lookUp(exercise, scopedTo: here) == nil)

        fixture.machine(for: exercise, at: gym, manufacturer: "Hammer Strength")

        #expect(MachineHint.lookUp(exercise, scopedTo: here) == nil)
    }

    @Test("With no machine resolved yet, every machine is a sibling")
    func theFirstMachineAtAGymSeesThemAll() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let elsewhere = fixture.gym("Old Barn")
        let sibling = fixture.machine(for: exercise, at: elsewhere, manufacturer: "Hammer Strength")
        fixture.log(sibling, reps: 5, weight: 55, on: .days(ago: 2))

        // The first log at a gym holding no machine for this exercise: nothing is
        // resolved, and the numbers you have are all somewhere else.
        let hint = try #require(MachineHint.lookUp(exercise, scopedTo: nil))

        #expect(hint.text == "\(kg(55)) kg × 5 on Hammer Strength")
    }

    @Test("An unlabelled sibling is named the one way machines are named")
    func anUnlabelledSiblingKeepsItsWord() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let sibling = fixture.machine(for: exercise, at: gym)
        fixture.log(sibling, reps: 5, weight: 55, on: .days(ago: 2))

        let hint = try #require(MachineHint.lookUp(exercise, scopedTo: here))

        #expect(hint.text == "\(kg(55)) kg × 5 on \(Machine.unlabelled)")
    }
}

/// A weight as this device would write it — the tests assert the phrasing, not the
/// decimal separator of whichever locale they happen to run in.
private func kg(_ weight: Double) -> String {
    weight.kilogramsText
}
