import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The 1.0.0 → 2.0.0 upgrade that goals arrive with (ADR-0004). The version is bumped in
/// place with no migration stage, so **whether SwiftData infers the additive migration on
/// its own is what this settles** — it could not be settled by reading.
///
/// `Fixtures/Chalk-1.0.0.store` was written by the app as 1.0.0 shipped (commit 7c66782):
/// Bench Press (free-weight, one entry of 5 × 100) and Chest Press (gym-bound, one entry of
/// 8 × 60 on `Plate-loaded` at Fitness X), both in Push, every entry at
/// 1_700_000_000. It is a real file rather than a test-only copy of the old models: two
/// `@Model` classes named `Machine` in one test process collide in SwiftData's entity
/// mapping while suites run in parallel, and crash whichever test loses the race.
@Suite("Schema migration")
struct SchemaMigrationTests {

    @Test("A store written with the 1.0.0 schema reopens with every row and no goals")
    func aShippedStoreUpgradesWithoutLosingARow() throws {
        let url = try TemporaryStore.unusedStoreURL()
        let shipped = try #require(
            Bundle(for: LibraryFixture.self).url(forResource: "Chalk-1.0.0", withExtension: "store")
        )
        try FileManager.default.copyItem(at: shipped, to: url)
        let loggedAt = Date(timeIntervalSince1970: 1_700_000_000)

        guard case .opened(let container) = ChalkStore.open(at: url) else {
            Issue.record("The 2.0.0 schema did not open a 1.0.0 store")
            return
        }
        let context = ModelContext(container)

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
        #expect(entries.allSatisfy { $0.date == loggedAt })
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
}
