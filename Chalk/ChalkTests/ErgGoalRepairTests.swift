import Foundation
import SwiftData
import Testing

@testable import Chalk

/// Endurance goals under the repairs that move entries between scopes — Merge, Move and
/// the kind change (SPEC §13.11, §7.5, §8, #121).
///
/// Two rules an implementer gets subtly wrong: **the most recently set goal wins**, read
/// off the shared `goalSetAt` and never off which machine is the loser; and **a carried
/// goal keeps its own `goalSetAt`** — it is the same goal wherever it lands, so its ring
/// still counts from the moment it was named.
@Suite("Endurance goals under merge, Move and kind change")
struct ErgGoalRepairTests {

    // MARK: - Merge

    @Test("Merging erg machines keeps the most recently set goal, whichever way you merge", arguments: [false, true])
    func theLatestEnduranceGoalWinsAMerge(reversed: Bool) throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let gym = fixture.gym("FitX")
        let unlabelled = fixture.machine(for: treadmill, at: gym)
        let excite = fixture.machine(for: treadmill, at: gym, label: "Technogym Excite")
        fixture.interval(treadmill, machine: unlabelled, on: .days(ago: 20))
        fixture.interval(treadmill, machine: excite, on: .days(ago: 1))
        let latest = Date.days(ago: 2)
        GoalScope.machine(unlabelled).set(zone: 4, duration: 360, intensity: 15.5, incline: 1, at: latest)
        GoalScope.machine(excite).set(zone: 3, duration: 600, intensity: 12.0, incline: 0, at: .days(ago: 9))
        let (loser, sibling) = reversed ? (excite, unlabelled) : (unlabelled, excite)

        fixture.gymsModel().merge(loser, into: sibling)

        let reopened = try fixture.afterRelaunch()
        let survivor = try #require(try reopened.fetch(FetchDescriptor<Machine>()).first)
        #expect(survivor.goalZone == 4)
        #expect(survivor.goalDuration == 360)
        #expect(survivor.goalIntensity == 15.5)
        #expect(survivor.goalIncline == 1)
        #expect(survivor.goalSetAt == latest)
        #expect(try reopened.fetchCount(FetchDescriptor<Entry>()) == 2)
    }

    @Test("A merge of two erg machines with goals names the kept one in endurance wording, and counts the other")
    func theMergeConfirmationGainsTheEnduranceClause() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let gym = fixture.gym("FitX")
        let loser = fixture.machine(for: treadmill, at: gym)
        let sibling = fixture.machine(for: treadmill, at: gym, label: "Technogym Excite")
        fixture.interval(treadmill, machine: loser)
        GoalScope.machine(loser).set(zone: 3, duration: 600, intensity: 12.0, incline: 0, at: .days(ago: 9))
        GoalScope.machine(sibling).set(zone: 4, duration: 360, intensity: 15.5, incline: 1, at: .days(ago: 2))

        #expect(MachineMerge(loser: loser, sibling: sibling, distanceUnit: .km).question.decimalPoint == "Move 1 entry to Technogym Excite and delete Unlabelled? Your goal of 15.5 km/h · 6:00 in Z4 · 1 % is kept; 1 other goal is cleared.")
    }

    @Test("An empty erg machine whose goal is kept says the goal moves")
    func anEmptyErgMachineSaysItsGoalMoves() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("Bike", unit: .watts)
        let gym = fixture.gym("FitX")
        let loser = fixture.machine(for: bike, at: gym, label: "Wattbike")
        let sibling = fixture.machine(for: bike, at: gym)
        fixture.interval(bike, machine: sibling, intensity: 240)
        GoalScope.machine(loser).set(zone: 3, duration: 600, intensity: 260, incline: nil)

        let merge = MachineMerge(loser: loser, sibling: sibling, distanceUnit: .km)

        #expect(merge.losersGoalIsKept)
        #expect(merge.question == "Move your goal of 260 W · 10:00 in Z3 to Unlabelled and delete Wattbike?")
    }

    // MARK: - Move

    @Test("Moving an erg machine to another gym takes its goal along, set when it was")
    func aMoveTakesTheErgGoalAlong() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let machine = fixture.machine(for: treadmill, at: fixture.gym("FitX Mitte"), label: "Technogym Excite")
        fixture.interval(treadmill, machine: machine)
        let setAt = Date.days(ago: 3)
        GoalScope.machine(machine).set(zone: 4, duration: 360, intensity: 15.5, incline: 1, at: setAt)

        fixture.gymsModel().move(machine, to: fixture.gym("FitX"))

        let reopened = try fixture.afterRelaunch()
        let moved = try #require(try reopened.fetch(FetchDescriptor<Machine>()).first)
        #expect(moved.gym?.name == "FitX")
        #expect(GoalScope.machine(moved).enduranceGoal(zones: nil, distanceUnit: .km)?.text.decimalPoint == "15.5 km/h · 6:00 in Z4 · 1 %")
        #expect(moved.goalSetAt == setAt)
    }

    @Test("Move's Merge into a passing machine takes the moving machine's goal when it is the later set")
    func movesMergeCarriesTheLaterGoal() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let fitX = fixture.gym("FitX")
        let theirs = fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")
        let mine = fixture.machine(for: treadmill, at: fixture.gym("FitX Mitte"), label: "Technogym excite")
        fixture.interval(treadmill, machine: theirs, on: .days(ago: 4))
        fixture.interval(treadmill, machine: mine, on: .days(ago: 3))
        let latest = Date.days(ago: 1)
        GoalScope.machine(theirs).set(zone: 3, duration: 600, intensity: 12.0, incline: 0, at: .days(ago: 6))
        GoalScope.machine(mine).set(zone: 4, duration: 360, intensity: 15.5, incline: 1, at: latest)
        try fixture.save()

        let merge = try #require(ErgModelMatch.onMove(mine, to: fitX)?.merge(from: mine, distanceUnit: .km))
        #expect(merge.question.decimalPoint == "Move 1 entry to Technogym Excite · FitX and delete Technogym excite · FitX Mitte? Your goal of 15.5 km/h · 6:00 in Z4 · 1 % is kept; 1 other goal is cleared.")
        fixture.gymsModel().move(merge.loser, mergingInto: merge.sibling)

        let reopened = try fixture.afterRelaunch()
        let survivor = try #require(try reopened.fetch(FetchDescriptor<Machine>()).first)
        #expect(survivor.id == theirs.id)
        #expect(GoalScope.machine(survivor).enduranceGoal(zones: nil, distanceUnit: .km)?.text.decimalPoint == "15.5 km/h · 6:00 in Z4 · 1 %")
        #expect(survivor.goalSetAt == latest)
    }

    // MARK: - Kind change to gym-bound

    @Test("A transferable erg with a goal and nothing logged is still asked which machine it is on")
    func aGoalAloneAsksForTheMachine() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("Bike", unit: .watts, kind: .freeWeight)
        GoalScope.exercise(bike).set(zone: 3, duration: 600, intensity: 260, incline: nil)

        let change = KindChange(exercise: bike, distanceUnit: .km)

        #expect(change.needsAMachine)
        #expect(change.prompt == "Which machine is this on?")
        #expect(change.promptDetail == "Bike becomes gym-bound, and your goal of 260 W · 10:00 in Z3 moves to the machine you pick.")
    }

    @Test("The erg's goal moves to the machine you pick, keeping when it was set")
    func theErgsGoalMovesToThePickedMachine() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, on: .days(ago: 2))
        let setAt = Date.days(ago: 5)
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 15.5, incline: 1, at: setAt)
        let gym = fixture.gym("FitX")
        try fixture.save()

        // The sentence has a comma of its own, so the locale's decimal is written in.
        let fifteenPointFive = "15\(WeightText.decimalSeparator)5"
        #expect(KindChange(exercise: treadmill, distanceUnit: .km).promptDetail == "Treadmill becomes gym-bound, and 1 entry and your goal of \(fifteenPointFive) km/h · 6:00 in Z4 · 1 % move to the machine you pick.")
        fixture.ergDetailModel(for: treadmill).makeGymBound(at: gym, named: "Technogym Excite")

        let reopened = try fixture.afterRelaunch()
        let erg = try #require(try reopened.fetch(FetchDescriptor<Exercise>()).first)
        let machine = try #require(erg.machines?.first)
        #expect(GoalScope.machine(machine).enduranceGoal(zones: nil, distanceUnit: .km)?.text.decimalPoint == "15.5 km/h · 6:00 in Z4 · 1 %")
        #expect(machine.goalSetAt == setAt)
        // A gym-bound erg holds no goal of its own.
        #expect(GoalScope.exercise(erg).enduranceGoal(zones: nil, distanceUnit: .km) == nil)
        #expect(erg.goalSetAt == nil)
    }

    @Test("A goal with nothing logged moves to the new machine too")
    func aGoalWithNoEntriesMovesToTheMachine() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("Bike", unit: .watts, kind: .freeWeight)
        GoalScope.exercise(bike).set(zone: 3, duration: 600, intensity: 260, incline: nil)
        let gym = fixture.gym("FitX")
        try fixture.save()
        let model = fixture.ergDetailModel(for: bike)

        // The flip that asks nothing is refused: there is a goal to place.
        model.makeGymBound()
        #expect(!bike.isGymBound)

        model.makeGymBound(at: gym, named: "Wattbike")

        let machine = try #require(bike.machines?.first)
        #expect(GoalScope.machine(machine).enduranceGoal(zones: nil, distanceUnit: .km)?.text == "260 W · 10:00 in Z3")
        #expect(model.goal?.text == "260 W · 10:00 in Z3")
    }

    // MARK: - Kind change to transferable

    @Test("Pooling an erg states the goals it clears with the endurance clause, naming the one kept")
    func poolingStatesTheClearedGoals() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("Bike", unit: .watts)
        let gym = fixture.gym("FitX")
        let machines = ["Wattbike", "Keiser", "Concept2"].map { fixture.machine(for: bike, at: gym, label: $0) }
        for machine in machines { fixture.interval(bike, machine: machine, intensity: 240) }
        let base = "Bike has entries on 3 machines. They'll be read as one."

        GoalScope.machine(machines[0]).set(zone: 3, duration: 600, intensity: 260, incline: nil, at: .days(ago: 1))
        #expect(KindChange(exercise: bike, distanceUnit: .km).question == base)

        GoalScope.machine(machines[1]).set(zone: 4, duration: 300, intensity: 300, incline: nil, at: .days(ago: 4))
        #expect(KindChange(exercise: bike, distanceUnit: .km).question == "\(base) Your goal of 260 W · 10:00 in Z3 is kept; 1 other goal is cleared.")

        GoalScope.machine(machines[2]).set(zone: 2, duration: 1200, intensity: 200, incline: nil, at: .days(ago: 6))
        #expect(KindChange(exercise: bike, distanceUnit: .km).question == "\(base) Your goal of 260 W · 10:00 in Z3 is kept; 2 other goals are cleared.")
    }

    @Test("With nothing logged the endurance clause stands alone")
    func theEnduranceClauseStandsAloneWithNoEntries() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("Bike", unit: .watts)
        let gym = fixture.gym("FitX")
        let wattbike = fixture.machine(for: bike, at: gym, label: "Wattbike")
        let keiser = fixture.machine(for: bike, at: gym, label: "Keiser")
        GoalScope.machine(wattbike).set(zone: 3, duration: 600, intensity: 260, incline: nil, at: .days(ago: 1))
        GoalScope.machine(keiser).set(zone: 4, duration: 300, intensity: 300, incline: nil, at: .days(ago: 4))

        #expect(KindChange(exercise: bike, distanceUnit: .km).question == "Your goal of 260 W · 10:00 in Z3 is kept; 1 other goal is cleared.")
    }

    @Test("Pooling keeps the most recently set machine goal on the erg, set when it was, and clears the rest")
    func poolingKeepsTheLatestGoalOnTheErg() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let fitX = fixture.gym("FitX")
        let excite = fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")
        let matrix = fixture.machine(for: treadmill, at: fixture.gym("Old Barn"), label: "Matrix")
        fixture.interval(treadmill, machine: excite, on: .days(ago: 3))
        fixture.interval(treadmill, machine: matrix, on: .days(ago: 2))
        let latest = Date.days(ago: 1)
        GoalScope.machine(excite).set(zone: 3, duration: 600, intensity: 12.0, incline: 0, at: .days(ago: 8))
        GoalScope.machine(matrix).set(zone: 4, duration: 360, intensity: 15.5, incline: 1, at: latest)
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        model.makeTransferable()

        #expect(model.goal?.text.decimalPoint == "15.5 km/h · 6:00 in Z4 · 1 %")
        let reopened = try fixture.afterRelaunch()
        let erg = try #require(try reopened.fetch(FetchDescriptor<Exercise>()).first)
        #expect(!erg.isGymBound)
        #expect(GoalScope.exercise(erg).enduranceGoal(zones: nil, distanceUnit: .km)?.text.decimalPoint == "15.5 km/h · 6:00 in Z4 · 1 %")
        #expect(erg.goalSetAt == latest)
        #expect(try reopened.fetchCount(FetchDescriptor<Machine>()) == 0)
        #expect(try reopened.fetchCount(FetchDescriptor<Entry>()) == 2)
    }
}
