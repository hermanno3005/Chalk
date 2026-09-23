import Foundation
import SwiftData
import Testing

@testable import Chalk

/// `Change kind` — the free-weight ↔ gym-bound flip (SPEC §8, #33).
///
/// Both directions are one decision, and the line every test here is measured against is
/// the same as the merge's: **no entry is lost**. Deleting a `Machine` cascades to its
/// entries (SPEC §3), so pooling has to detach every entry and flush before a single
/// machine row goes.
@Suite("Change kind")
struct ChangeKindTests {

    // MARK: - The words

    @Test("Pooling names the consequence out loud, with the machine count")
    func poolingNamesTheMachineCount() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        for label in ["Hammer Strength", "Cybex", "Green"] {
            fixture.log(fixture.machine(for: bench, at: gym, label: label), reps: 5, weight: 100)
        }

        let change = KindChange(exercise: bench)

        #expect(change.direction == .toFreeWeight)
        #expect(change.question == "Bench Press has entries on 3 machines. They'll merge into one curve.")
        #expect(change.detail.contains("Every entry is kept"))
        #expect(change.detail.contains("3 machines"))
        #expect(change.confirmButton == "Make free-weight")
    }

    @Test("One machine is not a merge, and says so")
    func poolingFromASingleMachineIsNotAMerge() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let machine = fixture.machine(for: bench, at: fixture.gym("Fitness X"))
        fixture.log(machine, reps: 5, weight: 100)

        let change = KindChange(exercise: bench)

        #expect(change.question == "Bench Press has entries on one machine. They'll become the exercise's own curve.")
    }

    @Test("A gym-bound exercise with nothing logged is asked a plain question")
    func poolingWithNothingLoggedIsPlain() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        fixture.machine(for: bench, at: fixture.gym("Fitness X"))

        let change = KindChange(exercise: bench)

        #expect(change.question == "Make Bench Press free-weight?")
        #expect(change.detail.contains("1 machine"))
    }

    @Test("The other direction asks which machine the existing entries belong to")
    func theFlipToGymBoundAsksForAMachine() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 100)
        fixture.log(bench, reps: 8, weight: 90)

        let change = KindChange(exercise: bench)

        #expect(change.direction == .toGymBound)
        #expect(change.needsAMachine)
        #expect(change.prompt == "Which machine are these entries on?")
        #expect(change.promptDetail.contains("2 entries"))
    }

    @Test("With nothing logged there is no machine to ask about — the flip is a plain confirmation")
    func theFlipToGymBoundWithNothingLoggedAsksNothing() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")

        let change = KindChange(exercise: bench)

        #expect(!change.needsAMachine)
        #expect(change.question == "Make Bench Press gym-bound?")
        #expect(change.confirmButton == "Make gym-bound")
    }

    // MARK: - Free-weight → gym-bound

    @Test("Every existing entry moves to the one machine, and none is lost")
    func everyEntryMovesToTheMachine() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 100, on: .days(ago: 3))
        fixture.log(bench, reps: 8, weight: 90, on: .days(ago: 2))
        fixture.log(bench, reps: 3, weight: 110, on: .days(ago: 1))
        let gym = fixture.gym("Fitness X")
        try fixture.save()
        let model = fixture.detailModel(for: bench)

        model.makeGymBound(at: gym, named: "Hammer Strength")

        let machine = try #require(bench.machines?.first)
        #expect(machine.name == "Hammer Strength")
        #expect(machine.gym === gym)
        #expect(bench.entries?.count == 3)
        #expect(bench.entries?.allSatisfy { $0.machine === machine } == true)

        let reopened = try fixture.afterRelaunch()
        #expect(try reopened.fetchCount(FetchDescriptor<Entry>()) == 3)
        #expect(try reopened.fetch(FetchDescriptor<Entry>()).allSatisfy { $0.machine != nil })
    }

    @Test("The screen changes shape: the qualifier appears and the curve derives from the machine")
    func theScreenBecomesGymBound() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 100)
        let gym = fixture.gym("Fitness X")
        try fixture.save()
        let model = fixture.detailModel(for: bench)
        #expect(!model.isGymBound)

        model.makeGymBound(at: gym, named: nil)

        #expect(model.isGymBound)
        #expect(model.machine === bench.machines?.first)
        #expect(model.machine?.name == Machine.unlabelled)
        // Scoped to the machine the entries just moved to, so the curve still stands.
        #expect(model.readout?.weight == 100)
        #expect(model.machineMenu.sections.count == 1)
    }

    @Test("Nothing logged means no machine at all — the empty state until the first log makes one")
    func theFlipWithNothingLoggedLeavesNoMachine() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        try fixture.save()
        let model = fixture.detailModel(for: bench)

        model.makeGymBound()

        #expect(model.isGymBound)
        #expect(bench.machines?.isEmpty == true)
        #expect(model.needsFirstMachine)
    }

    @Test("An exercise that is already gym-bound is refused")
    func theFlipToGymBoundIsRefusedWhenAlreadyGymBound() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let machine = fixture.machine(for: bench, at: fixture.gym("Fitness X"), label: "Cybex")
        fixture.log(machine, reps: 5, weight: 100)
        try fixture.save()
        let model = fixture.detailModel(for: bench)

        model.makeGymBound(at: fixture.gym("Old Barn"), named: "Nope")

        #expect(bench.machines?.count == 1)
        #expect(machine.entries?.count == 1)
    }

    // MARK: - Gym-bound → free-weight

    @Test("Pooling keeps every entry, nullifies the machine link and deletes the machines")
    func poolingKeepsEveryEntry() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let here = fixture.gym("Fitness X")
        let there = fixture.gym("Old Barn")
        let a = fixture.machine(for: bench, at: here, label: "Hammer Strength")
        let b = fixture.machine(for: bench, at: here, label: "Cybex")
        let c = fixture.machine(for: bench, at: there)
        fixture.log(a, reps: 5, weight: 100, on: .days(ago: 3))
        fixture.log(b, reps: 5, weight: 120, on: .days(ago: 2))
        fixture.log(c, reps: 8, weight: 80, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.detailModel(for: bench)

        model.makeFreeWeight()

        #expect(!bench.isGymBound)
        #expect(bench.machines?.isEmpty == true)
        #expect(bench.entries?.count == 3)
        #expect(bench.entries?.allSatisfy { $0.machine == nil } == true)

        // What actually reached the disk: three entries, no machines. The cascade from
        // `Machine` to its entries is the hazard this whole direction is written around.
        let reopened = try fixture.afterRelaunch()
        #expect(try reopened.fetchCount(FetchDescriptor<Entry>()) == 3)
        #expect(try reopened.fetchCount(FetchDescriptor<Machine>()) == 0)
        #expect(try reopened.fetch(FetchDescriptor<Entry>()).allSatisfy { $0.machine == nil })
    }

    @Test("The numbers merge into one curve, and the qualifier goes")
    func theCurvePoolsAfterwards() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let a = fixture.machine(for: bench, at: gym, label: "Hammer Strength")
        let b = fixture.machine(for: bench, at: gym, label: "Cybex")
        fixture.log(a, reps: 5, weight: 100, on: .days(ago: 2))
        fixture.log(b, reps: 5, weight: 120, on: .days(ago: 1))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(gym)
        let model = fixture.detailModel(for: bench, gyms: gyms)
        // Split in two beforehand: the machine in scope knows nothing of the other one.
        #expect(model.readout?.weight == 120)
        #expect(model.readout?.entriesBehind == 1)

        model.makeFreeWeight()

        #expect(!model.isGymBound)
        #expect(model.machine == nil)
        #expect(model.machines.isEmpty)
        #expect(model.machineMenu.isEmpty)
        #expect(model.readout?.weight == 120)
        #expect(model.readout?.entriesBehind == 2)
    }

    @Test("A machine with no entries of its own is deleted with the rest")
    func emptyMachinesGoToo() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let logged = fixture.machine(for: bench, at: gym, label: "Hammer Strength")
        fixture.machine(for: bench, at: gym, label: "Never used")
        fixture.log(logged, reps: 5, weight: 100)
        try fixture.save()

        fixture.detailModel(for: bench).makeFreeWeight()

        let reopened = try fixture.afterRelaunch()
        #expect(try reopened.fetchCount(FetchDescriptor<Machine>()) == 0)
        #expect(try reopened.fetchCount(FetchDescriptor<Entry>()) == 1)
    }

    @Test("The gyms are left alone — pooling deletes machines, not the places they stood in")
    func theGymsSurvive() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        fixture.log(fixture.machine(for: bench, at: gym), reps: 5, weight: 100)
        try fixture.save()

        fixture.detailModel(for: bench).makeFreeWeight()

        #expect(try fixture.afterRelaunch().fetchCount(FetchDescriptor<Gym>()) == 1)
    }

    @Test("Another exercise's machines and entries are untouched")
    func otherExercisesAreUntouched() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        fixture.log(fixture.machine(for: bench, at: gym), reps: 5, weight: 100)
        let theirs = fixture.machine(for: legPress, at: gym, label: "Cybex")
        fixture.log(theirs, reps: 5, weight: 200)
        try fixture.save()

        fixture.detailModel(for: bench).makeFreeWeight()

        #expect(legPress.machines?.count == 1)
        #expect(theirs.entries?.count == 1)
        #expect(try fixture.afterRelaunch().fetchCount(FetchDescriptor<Machine>()) == 1)
    }

    @Test("An entry with no exercise is neither repaired nor destroyed, and holds its machine up")
    func anOrphanEntryIsLeftAlone() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let machine = fixture.machine(for: bench, at: gym, label: "Hammer Strength")
        fixture.log(machine, reps: 5, weight: 100)
        // Not a state this app writes: an entry with a nil exercise is treated as
        // non-existent — never repaired, never surfaced, never counted (SPEC §3,
        // invariant 2). Pooling neither adopts it nor cascades over it.
        fixture.context.insert(Entry(reps: 5, weight: 60, machine: machine))
        try fixture.save()

        fixture.detailModel(for: bench).makeFreeWeight()

        let reopened = try fixture.afterRelaunch()
        #expect(try reopened.fetchCount(FetchDescriptor<Entry>()) == 2)
        // The machine is left standing rather than taken down over the row it still
        // holds: a stranded row is a nuisance, a lost entry is not.
        #expect(try reopened.fetchCount(FetchDescriptor<Machine>()) == 1)
        // The exercise's own entry pooled all the same.
        #expect(bench.entries?.allSatisfy { $0.machine == nil } == true)
    }

    @Test("A free-weight exercise is refused — there is nothing to pool")
    func poolingIsRefusedOnAFreeWeightExercise() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 100)
        try fixture.save()
        let model = fixture.detailModel(for: bench)

        model.makeFreeWeight()

        #expect(!bench.isGymBound)
        #expect(bench.entries?.count == 1)
    }

    // MARK: - Goals (#78)

    @Test("A goal with nothing logged still asks for a machine, in words that fit no entries")
    func aGoalWithNothingLoggedAsksForAMachine() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        GoalScope.exercise(bench).set(reps: 5, weight: 140)

        let change = KindChange(exercise: bench)

        #expect(change.needsAMachine)
        #expect(change.prompt == "Which machine is this on?")
        #expect(change.promptDetail == "Bench Press becomes gym-bound, and your goal of 140 × 5 moves to the machine you pick.")
    }

    @Test("Entries and a goal both move, and the prompt says so")
    func thePromptNamesTheGoalBesideTheEntries() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 100)
        GoalScope.exercise(bench).set(reps: 5, weight: 140)

        let change = KindChange(exercise: bench)

        #expect(change.prompt == "Which machine are these entries on?")
        #expect(change.promptDetail == "Bench Press becomes gym-bound, and 1 entry and your goal of 140 × 5 move to the machine you pick.")
    }

    @Test("The goal moves onto the machine, keeping when it was set, and leaves the exercise")
    func theGoalMovesToTheMachine() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 100, on: .days(ago: 3))
        let setAt = Date.days(ago: 5)
        GoalScope.exercise(bench).set(reps: 5, weight: 140, at: setAt)
        let gym = fixture.gym("Fitness X")
        try fixture.save()
        let model = fixture.detailModel(for: bench)

        model.makeGymBound(at: gym, named: "Hammer Strength")

        let machine = try #require(bench.machines?.first)
        let goal = try #require(GoalScope.machine(machine).goal)
        #expect(goal.reps == 5)
        #expect(goal.weight == 140)
        #expect(goal.setAt == setAt)
        #expect(model.goalLine?.text == "Goal 140 × 5 · 40 kg to go")

        let reopened = try fixture.afterRelaunch()
        #expect(try reopened.fetchCount(FetchDescriptor<Entry>()) == 1)
        #expect(try reopened.fetch(FetchDescriptor<Entry>()).allSatisfy { $0.machine != nil })
        let exercise = try #require(try reopened.fetch(FetchDescriptor<Exercise>()).first)
        #expect(exercise.goalReps == nil)
        #expect(exercise.goalWeight == nil)
        #expect(exercise.goalSetAt == nil)
        let stored = try #require(try reopened.fetch(FetchDescriptor<Machine>()).first)
        #expect(stored.goalReps == 5)
        #expect(stored.goalWeight == 140)
        #expect(stored.goalSetAt == setAt)
    }

    @Test("A goal with nothing logged moves onto the machine it prompted for")
    func aGoalWithNoEntriesMovesToTheMachine() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        GoalScope.exercise(bench).set(reps: 5, weight: 140)
        let gym = fixture.gym("Fitness X")
        try fixture.save()
        let model = fixture.detailModel(for: bench)

        model.makeGymBound(at: gym, named: nil)

        let machine = try #require(bench.machines?.first)
        #expect(GoalScope.machine(machine).goal?.text == "140 × 5")
        #expect(bench.goalReps == nil && bench.goalWeight == nil && bench.goalSetAt == nil)
        #expect(model.goalLine?.text == "Goal 140 × 5 · 140 kg to go")
    }

    @Test("The flip that asks nothing is refused where a goal needs a machine")
    func thePlainFlipIsRefusedOverAGoal() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        GoalScope.exercise(bench).set(reps: 5, weight: 140)
        try fixture.save()
        let model = fixture.detailModel(for: bench)

        model.makeGymBound()

        #expect(!bench.isGymBound)
        #expect(GoalScope.exercise(bench).goal != nil)
    }

    @Test("Pooling keeps the most recently set goal, whatever order the machines are in", arguments: [false, true])
    func theLatestGoalWins(reversed: Bool) throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let labels = reversed ? ["Cybex", "Hammer Strength"] : ["Hammer Strength", "Cybex"]
        let machines = labels.map { fixture.machine(for: bench, at: gym, label: $0) }
        let hammer = try #require(machines.first { $0.label == "Hammer Strength" })
        let cybex = try #require(machines.first { $0.label == "Cybex" })
        fixture.log(hammer, reps: 5, weight: 100, on: .days(ago: 20))
        fixture.log(cybex, reps: 5, weight: 120, on: .days(ago: 20))
        let latest = Date.days(ago: 2)
        GoalScope.machine(hammer).set(reps: 5, weight: 140, at: latest)
        GoalScope.machine(cybex).set(reps: 3, weight: 150, at: .days(ago: 9))
        try fixture.save()

        fixture.detailModel(for: bench).makeFreeWeight()

        let reopened = try fixture.afterRelaunch()
        let exercise = try #require(try reopened.fetch(FetchDescriptor<Exercise>()).first)
        #expect(exercise.goalReps == 5)
        #expect(exercise.goalWeight == 140)
        #expect(exercise.goalSetAt == latest)
        #expect(try reopened.fetchCount(FetchDescriptor<Entry>()) == 2)
        #expect(try reopened.fetchCount(FetchDescriptor<Machine>()) == 0)
    }

    @Test("The kept goal is measured against the pooled entries")
    func theKeptGoalIsMeasuredAgainstThePool() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let hammer = fixture.machine(for: bench, at: gym, label: "Hammer Strength")
        let cybex = fixture.machine(for: bench, at: gym, label: "Cybex")
        fixture.log(hammer, reps: 5, weight: 100, on: .days(ago: 20))
        fixture.log(cybex, reps: 5, weight: 120, on: .days(ago: 20))
        GoalScope.machine(hammer).set(reps: 5, weight: 140, at: .days(ago: 2))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(gym)
        let model = fixture.detailModel(for: bench, gyms: gyms)

        model.makeFreeWeight()

        // Hammer Strength alone had 100 to go from; the pool has Cybex's 120.
        #expect(model.goalLine?.text == "Goal 140 × 5 · 20 kg to go")
    }

    @Test("A gym-bound exercise's own goal fields stay nil, before and after it is made so")
    func theExerciseHoldsNoGoalWhileGymBound() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 100)
        GoalScope.exercise(bench).set(reps: 5, weight: 140)
        try fixture.save()
        let model = fixture.detailModel(for: bench)

        model.makeGymBound(at: fixture.gym("Fitness X"), named: nil)
        let machine = try #require(bench.machines?.first)
        GoalScope.machine(machine).set(reps: 3, weight: 150)
        try fixture.save()

        #expect(bench.goalReps == nil)
        #expect(bench.goalWeight == nil)
        #expect(bench.goalSetAt == nil)
    }

    @Test("The confirmation gains the lost-goal clause only when a goal is lost")
    func theClauseAppearsOnlyOnLoss() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let machines = ["Hammer Strength", "Cybex", "Green"].map { fixture.machine(for: bench, at: gym, label: $0) }
        for machine in machines { fixture.log(machine, reps: 5, weight: 100) }
        let base = "Bench Press has entries on 3 machines. They'll merge into one curve."

        #expect(KindChange(exercise: bench).question == base)

        GoalScope.machine(machines[0]).set(reps: 5, weight: 140, at: .days(ago: 1))
        #expect(KindChange(exercise: bench).question == base)

        GoalScope.machine(machines[1]).set(reps: 3, weight: 150, at: .days(ago: 4))
        #expect(KindChange(exercise: bench).question == "\(base) Your goal of 140 × 5 is kept; 1 other goal is cleared.")

        GoalScope.machine(machines[2]).set(reps: 8, weight: 120, at: .days(ago: 6))
        #expect(KindChange(exercise: bench).question == "\(base) Your goal of 140 × 5 is kept; 2 other goals are cleared.")
    }

    @Test("With nothing logged the entry sentence goes and the clause stands alone")
    func theClauseStandsAloneWithNoEntries() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let hammer = fixture.machine(for: bench, at: gym, label: "Hammer Strength")
        let cybex = fixture.machine(for: bench, at: gym, label: "Cybex")
        GoalScope.machine(hammer).set(reps: 5, weight: 140, at: .days(ago: 1))
        GoalScope.machine(cybex).set(reps: 3, weight: 150, at: .days(ago: 4))

        #expect(KindChange(exercise: bench).question == "Your goal of 140 × 5 is kept; 1 other goal is cleared.")
    }

    @Test("The clause is one sentence, shared word for word with the merge")
    func theClauseIsOneSentence() {
        let goal = Goal(reps: 5, weight: 140, setAt: .now, entries: [])
        #expect(goal?.lostGoalClause(clearing: 1) == "Your goal of 140 × 5 is kept; 1 other goal is cleared.")
        #expect(goal?.lostGoalClause(clearing: 3) == "Your goal of 140 × 5 is kept; 3 other goals are cleared.")
    }
}
