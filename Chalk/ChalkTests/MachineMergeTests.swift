import Foundation
import SwiftData
import Testing

@testable import Chalk

/// `Merge into…` — the repair for a split machine (SPEC §7.5, #32).
///
/// The line every test here is measured against is the hazard `GymsModel.merge(_:into:)`
/// documents: the delete cascade must never reach an entry the merge existed to save.
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
    }

    // MARK: - The confirmation

    @Test("The confirmation is the outcome, with both machines and both counts")
    func theConfirmationNamesBothMachinesAndBothCounts() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        for day in 1...8 {
            fixture.log(loser, reps: 5, weight: 100, on: .days(ago: day))
        }
        for day in 1...3 {
            fixture.log(sibling, reps: 5, weight: 105, on: .days(ago: day))
        }

        let merge = MachineMerge(loser: loser, sibling: sibling)

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
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(loser, reps: 5, weight: 100)

        let merge = MachineMerge(loser: loser, sibling: sibling)

        #expect(merge.question == "Move 1 entry to Hammer Strength and delete Green?")
        #expect(merge.detail == "Hammer Strength holds 1 entry afterwards. This cannot be undone.")
    }

    @Test("An empty loser is still a deletion, and the confirmation says so")
    func theConfirmationSaysWhenThereIsNothingToMove() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym, label: "Green")
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(sibling, reps: 5, weight: 105)

        let merge = MachineMerge(loser: loser, sibling: sibling)

        #expect(merge.question == "Delete Green?")
        #expect(merge.detail == "Green holds no entries. Hammer Strength keeps its 1 entry. This cannot be undone.")
    }

    // MARK: - Goals (#79)

    /// The four rows of SPEC §7.5's table: the text gains the lost-goal clause only
    /// where both machines hold a goal.
    @Test(
        "The confirmation gains the lost-goal clause only when both machines hold a goal",
        arguments: [
            (false, false, "Move 8 entries to Hammer Strength and delete Unlabelled?"),
            (true, false, "Move 8 entries to Hammer Strength and delete Unlabelled?"),
            (false, true, "Move 8 entries to Hammer Strength and delete Unlabelled?"),
            (true, true, "Move 8 entries to Hammer Strength and delete Unlabelled? Your goal of 140 × 5 is kept; 1 other goal is cleared."),
        ]
    )
    func theConfirmationNamesALostGoal(loserHasGoal: Bool, siblingHasGoal: Bool, question: String) throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        for day in 1...8 {
            fixture.log(loser, reps: 5, weight: 100, on: .days(ago: day))
        }
        if loserHasGoal {
            GoalScope.machine(loser).set(reps: 5, weight: 140, at: .days(ago: 2))
        }
        if siblingHasGoal {
            GoalScope.machine(sibling).set(reps: 3, weight: 150, at: .days(ago: 9))
        }

        #expect(MachineMerge(loser: loser, sibling: sibling).question == question)
    }

    @Test("The clause names the goal that is kept, even when it is the sibling's")
    func theClauseNamesTheSiblingsGoalWhenItWins() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(loser, reps: 5, weight: 100)
        GoalScope.machine(loser).set(reps: 3, weight: 150, at: .days(ago: 9))
        GoalScope.machine(sibling).set(reps: 5, weight: 140, at: .days(ago: 2))

        #expect(MachineMerge(loser: loser, sibling: sibling).question == "Move 1 entry to Hammer Strength and delete Unlabelled? Your goal of 140 × 5 is kept; 1 other goal is cleared.")
    }

    @Test("Goals set at the same moment still pick one winner, whichever way round")
    func aTieDoesNotDependOnDirection() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let unlabelled = fixture.machine(for: legPress, at: gym)
        let hammer = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        let moment = Date.days(ago: 2)
        GoalScope.machine(unlabelled).set(reps: 5, weight: 140, at: moment)
        GoalScope.machine(hammer).set(reps: 3, weight: 150, at: moment)

        #expect(MachineGoals([unlabelled, hammer]).keeping === MachineGoals([hammer, unlabelled]).keeping)
    }

    @Test("An empty loser whose goal is kept over the sibling's says both")
    func anEmptyLoserWhoseGoalWinsNamesTheLoss() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        let sibling = fixture.machine(for: legPress, at: gym)
        fixture.log(sibling, reps: 5, weight: 100)
        GoalScope.machine(loser).set(reps: 5, weight: 140, at: .days(ago: 2))
        GoalScope.machine(sibling).set(reps: 3, weight: 150, at: .days(ago: 9))

        #expect(MachineMerge(loser: loser, sibling: sibling).question == "Move your goal of 140 × 5 to Unlabelled and delete Hammer Strength? Your goal of 140 × 5 is kept; 1 other goal is cleared.")
    }

    @Test("An empty loser whose goal is kept says the goal moves")
    func anEmptyLoserSaysItsGoalMoves() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        let sibling = fixture.machine(for: legPress, at: gym)
        fixture.log(sibling, reps: 5, weight: 100)
        GoalScope.machine(loser).set(reps: 5, weight: 140)

        let merge = MachineMerge(loser: loser, sibling: sibling)

        #expect(merge.question == "Move your goal of 140 × 5 to Unlabelled and delete Hammer Strength?")
    }

    @Test("An empty loser whose goal is lost is a deletion that names the loss")
    func anEmptyLoserSaysItsGoalIsLost() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        let sibling = fixture.machine(for: legPress, at: gym)
        fixture.log(sibling, reps: 5, weight: 100)
        GoalScope.machine(loser).set(reps: 3, weight: 150, at: .days(ago: 9))
        GoalScope.machine(sibling).set(reps: 5, weight: 140, at: .days(ago: 2))

        let merge = MachineMerge(loser: loser, sibling: sibling)

        #expect(merge.question == "Delete Hammer Strength? Your goal of 140 × 5 is kept; 1 other goal is cleared.")
    }

    @Test("The most recently set goal ends up on the survivor, whichever way you merge", arguments: [false, true])
    func theLatestGoalWinsEitherWay(reversed: Bool) throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let unlabelled = fixture.machine(for: legPress, at: gym)
        let hammer = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(unlabelled, reps: 5, weight: 100, on: .days(ago: 20))
        fixture.log(hammer, reps: 5, weight: 110, on: .days(ago: 1))
        let latest = Date.days(ago: 2)
        GoalScope.machine(unlabelled).set(reps: 5, weight: 140, at: latest)
        GoalScope.machine(hammer).set(reps: 3, weight: 150, at: .days(ago: 9))
        let (loser, sibling) = reversed ? (hammer, unlabelled) : (unlabelled, hammer)

        fixture.gymsModel().merge(loser, into: sibling)

        let reopened = try fixture.afterRelaunch()
        let survivor = try #require(try reopened.fetch(FetchDescriptor<Machine>()).first)
        #expect(survivor.goalReps == 5)
        #expect(survivor.goalWeight == 140)
        #expect(survivor.goalSetAt == latest)
        #expect(try reopened.fetchCount(FetchDescriptor<Entry>()) == 2)
        // Its ring origin recomputes over the pooled entries dated before it.
        let goal = try #require(GoalScope.machine(survivor).goal)
        #expect(goal.origin == 100)
        #expect(goal.current == 110)
    }

    @Test("The loser's goal survives its delete when the survivor had none")
    func theLosersGoalSurvivesTheDelete() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(loser, reps: 5, weight: 100)
        let setAt = Date.days(ago: 3)
        GoalScope.machine(loser).set(reps: 5, weight: 140, at: setAt)

        fixture.gymsModel().merge(loser, into: sibling)

        #expect(GoalScope.machine(sibling).goal?.text == "140 × 5")
        let reopened = try fixture.afterRelaunch()
        let survivor = try #require(try reopened.fetch(FetchDescriptor<Machine>()).first)
        #expect(survivor.name == "Hammer Strength")
        #expect(survivor.goalReps == 5)
        #expect(survivor.goalWeight == 140)
        #expect(survivor.goalSetAt == setAt)
    }

    @Test("An empty loser's goal survives too")
    func anEmptyLosersGoalSurvives() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        let sibling = fixture.machine(for: legPress, at: gym)
        GoalScope.machine(loser).set(reps: 5, weight: 140)

        fixture.gymsModel().merge(loser, into: sibling)

        let reopened = try fixture.afterRelaunch()
        let survivor = try #require(try reopened.fetch(FetchDescriptor<Machine>()).first)
        #expect(survivor.name == "Unlabelled")
        #expect(survivor.goalWeight == 140)
    }

    // MARK: - The write

    @Test("Every entry survives the merge and lands on the sibling")
    func everyEntrySurvivesTheMerge() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        for day in 1...8 {
            fixture.log(loser, reps: 5, weight: 100, on: .days(ago: day))
        }
        fixture.log(sibling, reps: 5, weight: 95, on: .days(ago: 0))
        let model = fixture.gymsModel()

        model.merge(loser, into: sibling)

        // The reassignment is flushed before the delete, so the cascade from `Machine`
        // to its entries finds nothing left to eat.
        #expect(sibling.entries?.count == 9)
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
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(loser, reps: 5, weight: 100)

        fixture.gymsModel().merge(loser, into: sibling)

        #expect(gym.machines?.map(\.name) == ["Hammer Strength"])
        let reopened = try fixture.afterRelaunch()
        let machines = try reopened.fetch(FetchDescriptor<Machine>())
        #expect(machines.map(\.name) == ["Hammer Strength"])
    }

    @Test("The sibling's curve is correct on the next read, with nothing to recompute")
    func theCurveIsSimplyCorrectAfterwards() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        // The split curve: the heavy history sits on the machine you stopped using.
        fixture.log(loser, reps: 5, weight: 120, on: .days(ago: 30))
        fixture.log(sibling, reps: 5, weight: 90, on: .days(ago: 1))
        let gyms = fixture.gymsModel()
        gyms.select(gym)

        gyms.merge(loser, into: sibling)

        #expect(RepMaxCurve.best(atLeast: 5, in: try #require(sibling.entries)) == 120)
        // And the screen that reads it needs no recomputation step (ADR-0002).
        let detail = fixture.detailModel(for: legPress, gyms: gyms)
        #expect(detail.machine === sibling)
        #expect(detail.readout?.weight == 120)
    }

    @Test("Merging is all-or-nothing: a zeroed row travels with the lifts")
    func everyRowTravels() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(loser, reps: 5, weight: 100)
        fixture.context.insert(Entry(reps: 0, weight: 0, exercise: legPress, machine: loser))

        fixture.gymsModel().merge(loser, into: sibling)

        #expect(sibling.entries?.count == 2)
        #expect(try fixture.afterRelaunch().fetchCount(FetchDescriptor<Entry>()) == 2)
    }

    @Test("A machine at another gym is refused as a sibling, and nothing is deleted")
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
