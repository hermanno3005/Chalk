import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The upgrades goals (1.0.0 → 2.0.0, ADR-0004) and endurance (2.0.0 → 3.0.0, ADR-0008)
/// arrive with. Each version is bumped in place with no migration stage, so **whether
/// SwiftData infers the additive migration on its own is what this settles** — it could
/// not be settled by reading. Every field endurance adds must come up at its default, so
/// that a lift stays a lift and no strength group lands in the endurance half.
///
/// `Fixtures/Chalk-1.0.0.store` was written by the app as 1.0.0 shipped (commit 7c66782):
/// Bench Press (free-weight, one entry of 5 × 100) and Chest Press (gym-bound, one entry of
/// 8 × 60 on `Plate-loaded` at Fitness X), both in Push, every entry at
/// 1_700_000_000.
///
/// `Fixtures/Chalk-2.0.0.store` holds the same rows plus both kinds of strength goal: 5 ×
/// 140 on Bench Press, set at 1_700_100_000, and 8 × 72.5 on `Plate-loaded`, set at
/// 1_700_200_000. It was written at commit c9cc770, before any model file changed, by a
/// throwaway test (since removed) that opened `ChalkStore` at a host path from the
/// simulator and saved through the app's 2.0.0 models; `sqlite3` then checkpointed the
/// WAL and set the journal mode to delete, so the fixture is one file.
///
/// Both are real files rather than test-only copies of the old models: two `@Model`
/// classes named `Machine` in one test process collide in SwiftData's entity mapping while
/// suites run in parallel, and crash whichever test loses the race.
@Suite("Schema migration")
struct SchemaMigrationTests {

    private static let loggedAt = Date(timeIntervalSince1970: 1_700_000_000)

    /// A copy of the named fixture at a fresh path, so no test writes to the bundle's.
    private func copyOfFixture(_ name: String) throws -> URL {
        let url = try TemporaryStore.unusedStoreURL()
        let fixture = try #require(
            Bundle(for: LibraryFixture.self).url(forResource: name, withExtension: "store")
        )
        try FileManager.default.copyItem(at: fixture, to: url)
        return url
    }

    /// Every attribute schema 3.0.0 adds, at the default an upgraded row must come up
    /// with: no unit, no endurance goal, interval fields at 0, every group strength's.
    private func expectEveryEnduranceFieldAtItsDefault(in context: ModelContext) throws {
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) {
            #expect(exercise.unit == nil)
            #expect(!exercise.isErg)
            #expect(exercise.goalZone == nil)
            #expect(exercise.goalDuration == nil)
            #expect(exercise.goalIntensity == nil)
            #expect(exercise.goalIncline == nil)
        }
        for machine in try context.fetch(FetchDescriptor<Machine>()) {
            #expect(machine.goalZone == nil)
            #expect(machine.goalDuration == nil)
            #expect(machine.goalIntensity == nil)
            #expect(machine.goalIncline == nil)
        }
        for entry in try context.fetch(FetchDescriptor<Entry>()) {
            #expect(entry.duration == 0)
            #expect(entry.intensity == 0)
            #expect(entry.incline == 0)
            #expect(entry.averageHeartRate == 0)
            #expect(entry.peakHeartRate == 0)
            #expect(entry.isALift)
            #expect(!entry.isAnInterval)
        }
        for group in try context.fetch(FetchDescriptor<ExerciseGroup>()) {
            #expect(group.half == Half.strength.rawValue)
        }
    }

    @Test("A store written with the 1.0.0 schema reopens with every row and no goals")
    func aShippedStoreUpgradesWithoutLosingARow() throws {
        let url = try copyOfFixture("Chalk-1.0.0")

        guard case .opened(let container) = ChalkStore.open(at: url) else {
            Issue.record("The 3.0.0 schema did not open a 1.0.0 store")
            return
        }
        let context = ModelContext(container)
        try expectEveryEnduranceFieldAtItsDefault(in: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        #expect(exercises.map(\.name) == ["Bench Press", "Chest Press"])
        #expect(exercises.map(\.isGymBound) == [false, true])
        #expect(exercises.allSatisfy { $0.group?.name == "Push" })
        for exercise in exercises {
            #expect(exercise.goalReps == nil)
            #expect(exercise.goalWeight == nil)
            #expect(exercise.goalSetAt == nil)
        }

        let machine = try #require(try context.fetch(FetchDescriptor<Machine>()).first)
        #expect(machine.label == "Plate-loaded")
        #expect(machine.gym?.name == "Fitness X")
        #expect(machine.goalReps == nil)
        #expect(machine.goalWeight == nil)
        #expect(machine.goalSetAt == nil)

        let entries = try context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.reps)]))
        #expect(entries.map(\.reps) == [5, 8])
        #expect(entries.map(\.weight) == [100, 60])
        #expect(entries.allSatisfy { $0.date == Self.loggedAt })
        #expect(entries[0].exercise?.name == "Bench Press")
        #expect(entries[0].machine == nil)
        #expect(entries[1].machine?.id == machine.id)

        #expect(try context.fetchCount(FetchDescriptor<Gym>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseGroup>()) == 1)

        // And the upgraded store takes a goal like any other.
        GoalScope.exercise(exercises[0]).set(reps: 5, weight: 140)
        try context.save()
        let reread = try ModelContext(try TemporaryStore.reopen(at: url))
            .fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        #expect(reread.first?.goalWeight == 140)
    }

    @Test("A store written with the 2.0.0 schema reopens with every row, both goals and no endurance")
    func aGoalsStoreUpgradesWithoutLosingARow() throws {
        let url = try copyOfFixture("Chalk-2.0.0")

        guard case .opened(let container) = ChalkStore.open(at: url) else {
            Issue.record("The 3.0.0 schema did not open a 2.0.0 store")
            return
        }
        let context = ModelContext(container)
        try expectEveryEnduranceFieldAtItsDefault(in: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        #expect(exercises.map(\.name) == ["Bench Press", "Chest Press"])
        #expect(exercises.map(\.isGymBound) == [false, true])
        #expect(exercises.allSatisfy { $0.group?.name == "Push" })

        let benchGoal = try #require(GoalScope.exercise(exercises[0]).goal)
        #expect(benchGoal.reps == 5)
        #expect(benchGoal.weight == 140)
        #expect(benchGoal.setAt == Date(timeIntervalSince1970: 1_700_100_000))
        #expect(GoalScope.exercise(exercises[1]).goal == nil)

        let plateLoaded = try #require(try context.fetch(FetchDescriptor<Machine>()).first)
        #expect(plateLoaded.label == "Plate-loaded")
        #expect(plateLoaded.gym?.name == "Fitness X")
        let machineGoal = try #require(GoalScope.machine(plateLoaded).goal)
        #expect(machineGoal.reps == 8)
        #expect(machineGoal.weight == 72.5)
        #expect(machineGoal.setAt == Date(timeIntervalSince1970: 1_700_200_000))

        let entries = try context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.reps)]))
        #expect(entries.map(\.reps) == [5, 8])
        #expect(entries.map(\.weight) == [100, 60])
        #expect(entries.allSatisfy { $0.date == Self.loggedAt })
        #expect(entries[0].exercise?.name == "Bench Press")
        #expect(entries[0].machine == nil)
        #expect(entries[1].machine?.id == plateLoaded.id)

        #expect(try context.fetchCount(FetchDescriptor<Gym>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseGroup>()) == 1)

        // And the upgraded store takes a gym-bound speed erg, an interval and its
        // machine's endurance goal, at the same gym as the strength machine's goal.
        let fitnessX = try #require(plateLoaded.gym)
        let treadmill = Exercise(name: "Treadmill", kind: .gymBound, unit: .speed)
        let technogym = Machine(label: "Technogym Run", exercise: treadmill, gym: fitnessX)
        // Written past `GoalScope`, which has no endurance write yet: this is the store's
        // test, and it asks only that the fields hold beside a strength goal.
        technogym.goalZone = 4
        technogym.goalDuration = 360
        technogym.goalIntensity = 15.5
        technogym.goalIncline = 1
        technogym.goalSetAt = Date(timeIntervalSince1970: 1_700_300_000)
        let interval = Entry(
            duration: 360,
            intensity: 15.0,
            incline: 1,
            averageHeartRate: 164,
            peakHeartRate: 171,
            date: Date(timeIntervalSince1970: 1_700_250_000),
            exercise: treadmill,
            machine: technogym
        )
        context.insert(treadmill)
        context.insert(technogym)
        context.insert(interval)
        try context.save()

        let reread = ModelContext(try TemporaryStore.reopen(at: url))
        let gym = try #require(try reread.fetch(FetchDescriptor<Gym>()).first)
        let machines = (gym.machines ?? []).sorted { $0.name < $1.name }
        #expect(machines.map(\.name) == ["Plate-loaded", "Technogym Run"])

        let strengthGoal = try #require(GoalScope.machine(machines[0]).goal)
        #expect(strengthGoal.reps == 8)
        #expect(strengthGoal.weight == 72.5)
        #expect(machines[0].goalZone == nil)

        let ergMachine = machines[1]
        #expect(ergMachine.exercise?.ergUnit == .speed)
        #expect(ergMachine.exercise?.isGymBound == true)
        #expect(ergMachine.goalZone == 4)
        #expect(ergMachine.goalDuration == 360)
        #expect(ergMachine.goalIntensity == 15.5)
        #expect(ergMachine.goalIncline == 1)
        #expect(ergMachine.goalSetAt == Date(timeIntervalSince1970: 1_700_300_000))
        #expect(ergMachine.goalReps == nil)
        #expect(ergMachine.goalWeight == nil)

        let loggedInterval = try #require(ergMachine.entries?.first)
        #expect(loggedInterval.isAnInterval)
        #expect(!loggedInterval.isALift)
        #expect(loggedInterval.duration == 360)
        #expect(loggedInterval.intensity == 15.0)
        #expect(loggedInterval.incline == 1)
        #expect(loggedInterval.averageHeartRate == 164)
        #expect(loggedInterval.peakHeartRate == 171)
    }
}
