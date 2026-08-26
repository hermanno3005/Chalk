import Foundation
import SwiftData
import Testing

@testable import Chalk

@Suite("Schema round trip")
struct SchemaRoundTripTests {

    @Test("One of each entity survives a write and a reopen")
    func roundTripsEveryEntity() throws {
        let store = try TemporaryStore()
        let loggedAt = Date(timeIntervalSince1970: 1_700_000_000)

        do {
            let context = ModelContext(store.container)
            let group = ExerciseGroup(name: "Push", sortIndex: 3)
            let exercise = Exercise(name: "Chest Press", kind: .gymBound, group: group)
            let gym = Gym(name: "Fitness X")
            let machine = Machine(
                manufacturer: "Hammer Strength",
                label: "Plate-loaded",
                exercise: exercise,
                gym: gym
            )
            let entry = Entry(
                reps: 5,
                weight: 57.5,
                date: loggedAt,
                exercise: exercise,
                machine: machine
            )
            try store.insertAll([group, exercise, gym, machine, entry], into: context)
        }

        let context = ModelContext(try store.reopened())

        let exercise = try #require(try context.fetch(FetchDescriptor<Exercise>()).first)
        #expect(exercise.name == "Chest Press")
        #expect(exercise.kind == ExerciseKind.gymBound.rawValue)
        #expect(exercise.group?.name == "Push")

        let group = try #require(try context.fetch(FetchDescriptor<ExerciseGroup>()).first)
        #expect(group.sortIndex == 3)
        #expect(group.exercises?.map(\.name) == ["Chest Press"])

        let gym = try #require(try context.fetch(FetchDescriptor<Gym>()).first)
        #expect(gym.name == "Fitness X")
        #expect(gym.isArchived == false)
        #expect(gym.machines?.count == 1)

        let machine = try #require(try context.fetch(FetchDescriptor<Machine>()).first)
        #expect(machine.manufacturer == "Hammer Strength")
        #expect(machine.label == "Plate-loaded")
        #expect(machine.exercise?.id == exercise.id)
        #expect(machine.gym?.id == gym.id)

        let entry = try #require(try context.fetch(FetchDescriptor<Entry>()).first)
        #expect(entry.reps == 5)
        #expect(entry.weight == 57.5)
        #expect(entry.date == loggedAt)
        #expect(entry.exercise?.id == exercise.id)
        #expect(entry.machine?.id == machine.id)
        #expect(exercise.entries?.count == 1)
        #expect(machine.entries?.count == 1)
    }

    @Test("Defaults let every entity be created with nothing supplied")
    func defaultsAreEnoughToInsert() throws {
        let store = try TemporaryStore()
        let context = ModelContext(store.container)

        try store.insertAll([Exercise(), Entry(), Gym(), Machine(), ExerciseGroup()], into: context)

        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Gym>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Machine>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ExerciseGroup>()) == 1)
    }

    @Test("The v1 schema names all five entities")
    func schemaListsFiveEntities() {
        #expect(ChalkSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(ChalkSchemaV1.models.count == 5)
        #expect(ChalkMigrationPlan.schemas.count == 1)
        #expect(ChalkMigrationPlan.stages.isEmpty)
    }
}
