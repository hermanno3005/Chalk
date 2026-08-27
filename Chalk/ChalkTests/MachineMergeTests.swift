import Foundation
import SwiftData
import Testing

@testable import Chalk

/// `Merge into…` — the repair for a split machine (SPEC §7.5, #32).
///
/// The line every test here is measured against: **deletion cascades from `Machine` to
/// its entries**, so the merge must re-point every entry and flush the context *before*
/// it deletes the loser. Invert that and the cascade eats exactly the history the merge
/// existed to save.
@Suite("Merge into…")
struct MachineMergeTests {

    // MARK: - The picker

    @Test("Targets are the same-gym, same-exercise siblings, most recently logged first")
    func targetsAreSiblingsInRecencyOrder() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let unlabelled = fixture.machine(for: legPress, at: gym)
        let quiet = fixture.machine(for: legPress, at: gym, label: "Cybex")
        let recent = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(quiet, reps: 5, weight: 100, on: .days(ago: 30))
        fixture.log(recent, reps: 5, weight: 100, on: .days(ago: 1))

        #expect(MachineMerge.targets(for: unlabelled).map(\.name) == ["Hammer Strength", "Cybex"])
        // Never itself.
        #expect(MachineMerge.targets(for: recent).map(\.name) == ["Cybex", "Unlabelled"])
    }

    @Test("A machine at another gym is not a target — merging across gyms is incoherent")
    func targetsNeverCrossGyms() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let here = fixture.gym("Fitness X")
        let there = fixture.gym("Old Barn")
        let machine = fixture.machine(for: legPress, at: here)
        fixture.machine(for: legPress, at: there, label: "Hammer Strength")

        #expect(MachineMerge.targets(for: machine).isEmpty)
    }

    @Test("A machine for another exercise is not a target")
    func targetsNeverCrossExercises() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let chestPress = fixture.exercise("Chest Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let machine = fixture.machine(for: legPress, at: gym)
        fixture.machine(for: chestPress, at: gym, label: "Hammer Strength")

        #expect(MachineMerge.targets(for: machine).isEmpty)
    }

    @Test("No sibling means no targets — the verb is absent from the row, not disabled")
    func aLoneMachineOffersNoTargets() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let machine = fixture.machine(for: legPress, at: gym, label: "Green")
        fixture.log(machine, reps: 5, weight: 100)

        #expect(MachineMerge.targets(for: machine).isEmpty)
        #expect(fixture.gymsModel().mergeTargets(for: machine).isEmpty)
    }

    // MARK: - The confirmation

    @Test("The confirmation is the outcome, with both machines and both counts")
    func theConfirmationNamesBothMachinesAndBothCounts() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let winner = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        for day in 1...8 {
            fixture.log(loser, reps: 5, weight: 100, on: .days(ago: day))
        }
        for day in 1...3 {
            fixture.log(winner, reps: 5, weight: 105, on: .days(ago: day))
        }

        let merge = MachineMerge(loser: loser, winner: winner)

        #expect(merge.movingCount == 8)
        #expect(merge.resultingCount == 11)
        #expect(merge.question == "Move 8 entries to Hammer Strength and delete Unlabelled?")
        #expect(merge.detail == "Hammer Strength holds 11 entries afterwards. This cannot be undone.")
    }

    @Test("One entry is one entry")
    func theConfirmationCountsInSingular() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym, label: "Green")
        let winner = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(loser, reps: 5, weight: 100)

        let merge = MachineMerge(loser: loser, winner: winner)

        #expect(merge.question == "Move 1 entry to Hammer Strength and delete Green?")
        #expect(merge.detail == "Hammer Strength holds 1 entry afterwards. This cannot be undone.")
    }

    @Test("An empty loser is still a deletion, and the confirmation says so")
    func theConfirmationSaysWhenThereIsNothingToMove() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym, label: "Green")
        let winner = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(winner, reps: 5, weight: 105)

        let merge = MachineMerge(loser: loser, winner: winner)

        #expect(merge.question == "Delete Green and keep Hammer Strength?")
        #expect(merge.detail == "Green holds no entries. Hammer Strength keeps its 1 entry. This cannot be undone.")
    }

    // MARK: - The write

    @Test("Every entry survives the merge and lands on the winner")
    func everyEntrySurvivesTheMerge() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let winner = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        for day in 1...8 {
            fixture.log(loser, reps: 5, weight: 100, on: .days(ago: day))
        }
        fixture.log(winner, reps: 5, weight: 95, on: .days(ago: 0))
        let model = fixture.gymsModel()

        model.merge(loser, into: winner)

        // The reassignment is flushed before the delete, so the cascade from `Machine`
        // to its entries finds nothing left to eat.
        #expect(winner.entries?.count == 9)
        let reopened = try fixture.afterRelaunch()
        let entries = try reopened.fetch(FetchDescriptor<Entry>())
        #expect(entries.count == 9)
        #expect(entries.allSatisfy { $0.machine?.name == "Hammer Strength" })
    }

    @Test("The loser is hard-deleted — machines gain no archived state")
    func theLoserLeavesTheStore() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let winner = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(loser, reps: 5, weight: 100)

        fixture.gymsModel().merge(loser, into: winner)

        #expect(gym.machines?.map(\.name) == ["Hammer Strength"])
        let reopened = try fixture.afterRelaunch()
        let machines = try reopened.fetch(FetchDescriptor<Machine>())
        #expect(machines.map(\.name) == ["Hammer Strength"])
    }

    @Test("The winner's curve is correct on the next read, with nothing to recompute")
    func theCurveIsSimplyCorrectAfterwards() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let winner = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        // The split curve: the heavy history sits on the machine you stopped using.
        fixture.log(loser, reps: 5, weight: 120, on: .days(ago: 30))
        fixture.log(winner, reps: 5, weight: 90, on: .days(ago: 1))
        let gyms = fixture.gymsModel()
        gyms.select(gym)

        gyms.merge(loser, into: winner)

        #expect(RepMaxCurve.best(atLeast: 5, in: try #require(winner.entries)) == 120)
        // And the screen that reads it needs no recomputation step (ADR-0002).
        let detail = fixture.detailModel(for: legPress, gyms: gyms)
        #expect(detail.machine === winner)
        #expect(detail.readout?.weight == 120)
    }

    @Test("Merging is all-or-nothing: a zeroed row travels with the lifts")
    func everyRowTravels() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let winner = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(loser, reps: 5, weight: 100)
        fixture.context.insert(Entry(reps: 0, weight: 0, exercise: legPress, machine: loser))

        fixture.gymsModel().merge(loser, into: winner)

        #expect(winner.entries?.count == 2)
        #expect(try fixture.afterRelaunch().fetchCount(FetchDescriptor<Entry>()) == 2)
    }

    @Test("A machine at another gym is refused as a winner, and nothing is deleted")
    func mergingAcrossGymsIsRefused() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let here = fixture.gym("Fitness X")
        let there = fixture.gym("Old Barn")
        let loser = fixture.machine(for: legPress, at: here)
        let stranger = fixture.machine(for: legPress, at: there, label: "Hammer Strength")
        fixture.log(loser, reps: 5, weight: 100)
        try fixture.save()

        fixture.gymsModel().merge(loser, into: stranger)

        #expect(loser.entries?.count == 1)
        #expect(stranger.entries?.isEmpty == true)
        #expect(try fixture.afterRelaunch().fetchCount(FetchDescriptor<Machine>()) == 2)
    }

    @Test("Merging a machine into itself is refused — it would delete its own entries")
    func mergingIntoItselfIsRefused() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let machine = fixture.machine(for: legPress, at: gym, label: "Green")
        fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(machine, reps: 5, weight: 100)
        try fixture.save()

        fixture.gymsModel().merge(machine, into: machine)

        #expect(machine.entries?.count == 1)
        #expect(try fixture.afterRelaunch().fetchCount(FetchDescriptor<Entry>()) == 1)
        #expect(try fixture.afterRelaunch().fetchCount(FetchDescriptor<Machine>()) == 2)
    }
}
