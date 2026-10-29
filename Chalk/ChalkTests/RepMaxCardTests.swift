import Foundation
import Testing

@testable import Chalk

/// What Siri and a Spotlight tile show for *Bench press rep maxes in Chalk* (SPEC §15.5):
/// the twelve rep-maxes of the scope the detail screen would open on, a dash where
/// nothing is proven.
@Suite("Rep-max card")
struct RepMaxCardTests {

    @Test("The card holds all twelve rep-maxes, a dash where nothing is proven")
    func twelveValuesAndDashes() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 1, weight: 110)
        fixture.log(bench, reps: 5, weight: 95)
        fixture.log(bench, reps: 8, weight: 82.5)
        try fixture.save()

        let card = RepMaxCard(exercise: bench, gyms: fixture.gymsModel(), weightUnit: .kg)
        let eightyTwoPointFive = "82\(WeightText.decimalSeparator)5 kg"

        #expect(card.name == "Bench Press")
        #expect(card.machine == nil)
        #expect(card.cells.map(\.reps) == Array(1...12))
        #expect(card.cells.map(\.weight) == [
            "110 kg", "95 kg", "95 kg", "95 kg", "95 kg",
            eightyTwoPointFive, eightyTwoPointFive, eightyTwoPointFive,
            "—", "—", "—", "—",
        ])
        #expect(card.nothingLogged == nil)
    }

    @Test("A gym-bound exercise reads the machine the detail screen opens on, and names it")
    func aGymBoundCardReadsTheOpeningMachine() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let current = fixture.gym("Fitness X")
        let elsewhere = fixture.gym("Old Barn")
        let here = fixture.machine(for: legPress, at: current, label: "By the window")
        let there = fixture.machine(for: legPress, at: elsewhere, label: "Blue one")
        fixture.log(here, reps: 5, weight: 140, on: .days(ago: 9))
        fixture.log(there, reps: 5, weight: 200, on: .days(ago: 1))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(current)

        let card = RepMaxCard(exercise: legPress, gyms: gyms, weightUnit: .lb)

        #expect(card.machine == "By the window · Fitness X")
        #expect(card.cells.map(\.weight) == Array(repeating: "140 lb", count: 5) + Array(repeating: "—", count: 7))
    }

    @Test("A scope with nothing logged says so, though a machine at another gym has lifts")
    func nothingLoggedAtTheScope() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let current = fixture.gym("Fitness X")
        let elsewhere = fixture.gym("Old Barn")
        fixture.machine(for: legPress, at: current, label: "By the window")
        let there = fixture.machine(for: legPress, at: elsewhere, label: "Blue one")
        fixture.log(there, reps: 5, weight: 200)
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(current)

        let card = RepMaxCard(exercise: legPress, gyms: gyms, weightUnit: .kg)

        #expect(card.nothingLogged == "Nothing logged on Leg Press yet")
        #expect(card.machine == "By the window · Fitness X")
        #expect(card.cells.allSatisfy { $0.weight == "—" })
    }
}
