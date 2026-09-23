import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The 1.0.0 → 2.0.0 upgrade that goals arrive with (ADR-0004). The version is bumped in
/// place with no migration stage, so **whether SwiftData infers the additive migration on
/// its own is what this settles** — it could not be settled by reading.
@Suite("Schema migration")
struct SchemaMigrationTests {

    @Test("A store written with the 1.0.0 schema reopens with every row and no goals")
    func aShippedStoreUpgradesWithoutLosingARow() throws {
        let url = try TemporaryStore.unusedStoreURL()
        let loggedAt = Date(timeIntervalSince1970: 1_700_000_000)

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: ShippedSchema1.self),
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(container)
            let group = ShippedSchema1.ExerciseGroup(name: "Push", sortIndex: 2)
            let bench = ShippedSchema1.Exercise(name: "Bench Press", kind: "freeWeight", group: group)
            let press = ShippedSchema1.Exercise(name: "Chest Press", kind: "gymBound", group: group)
            let gym = ShippedSchema1.Gym(name: "Fitness X")
            let machine = ShippedSchema1.Machine(label: "Plate-loaded", exercise: press, gym: gym)
            context.insert(group)
            context.insert(bench)
            context.insert(press)
            context.insert(gym)
            context.insert(machine)
            context.insert(ShippedSchema1.Entry(reps: 5, weight: 100, date: loggedAt, exercise: bench))
            context.insert(ShippedSchema1.Entry(reps: 8, weight: 60, date: loggedAt, exercise: press, machine: machine))
            try context.save()
        }

        guard case .opened(let container) = ChalkStore.open(at: url) else {
            Issue.record("The 2.0.0 schema did not open a 1.0.0 store")
            return
        }
        let context = ModelContext(container)

        let exercises = try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        #expect(exercises.map(\.name) == ["Bench Press", "Chest Press"])
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
    }
}

/// **The schema as 1.0.0 shipped it**, frozen here and nowhere else: the app bumps its
/// one schema in place rather than keeping a V1 copy (ADR-0004), so this is the only
/// record of what a store on the phone was written with before goals.
enum ShippedSchema1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Exercise.self, Entry.self, Gym.self, Machine.self, ExerciseGroup.self]
    }

    @Model
    final class Exercise {
        var id: UUID = UUID()
        var name: String = ""
        var kind: String = "freeWeight"
        var group: ExerciseGroup?
        @Relationship(deleteRule: .cascade, inverse: \Entry.exercise)
        var entries: [Entry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Machine.exercise)
        var machines: [Machine]? = []

        init(name: String, kind: String, group: ExerciseGroup?) {
            self.name = name
            self.kind = kind
            self.group = group
        }
    }

    @Model
    final class Entry {
        var id: UUID = UUID()
        var reps: Int = 0
        var weight: Double = 0
        var date: Date = Date.now
        var exercise: Exercise?
        var machine: Machine?

        init(reps: Int, weight: Double, date: Date, exercise: Exercise?, machine: Machine? = nil) {
            self.reps = reps
            self.weight = weight
            self.date = date
            self.exercise = exercise
            self.machine = machine
        }
    }

    @Model
    final class Gym {
        var id: UUID = UUID()
        var name: String = ""
        var isArchived: Bool = false
        @Relationship(deleteRule: .nullify, inverse: \Machine.gym)
        var machines: [Machine]? = []

        init(name: String) {
            self.name = name
        }
    }

    @Model
    final class Machine {
        var id: UUID = UUID()
        var manufacturer: String?
        var label: String?
        var exercise: Exercise?
        var gym: Gym?
        @Relationship(deleteRule: .cascade, inverse: \Entry.machine)
        var entries: [Entry]? = []

        init(label: String?, exercise: Exercise?, gym: Gym?) {
            self.label = label
            self.exercise = exercise
            self.gym = gym
        }
    }

    @Model
    final class ExerciseGroup {
        var id: UUID = UUID()
        var name: String = ""
        var sortIndex: Int = 0
        @Relationship(deleteRule: .nullify, inverse: \Exercise.group)
        var exercises: [Exercise]? = []

        init(name: String, sortIndex: Int) {
            self.name = name
            self.sortIndex = sortIndex
        }
    }
}
