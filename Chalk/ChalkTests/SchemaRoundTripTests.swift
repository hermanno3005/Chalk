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
        let exerciseGoalSetAt = Date(timeIntervalSince1970: 1_700_100_000)
        let machineGoalSetAt = Date(timeIntervalSince1970: 1_700_200_000)

        do {
            let context = ModelContext(store.container)
            let group = ExerciseGroup(name: "Treadmills", sortIndex: 3, half: .endurance)
            let exercise = Exercise(name: "Chest Press", kind: .gymBound, group: group, unit: .speed)
            // The invariants keep a gym-bound row's goal fields nil and a row's goal
            // fields its own half's (SPEC §3), and a lift's entries have no interval
            // fields — but the schema holds every field either way. This is the schema's
            // test, not the app's.
            exercise.goalReps = 5
            exercise.goalWeight = 140
            exercise.goalSetAt = exerciseGoalSetAt
            exercise.goalZone = 4
            exercise.goalDuration = 360
            exercise.goalIntensity = 15.5
            exercise.goalIncline = 1
            let gym = Gym(name: "Fitness X")
            let machine = Machine(
                manufacturer: "Hammer Strength",
                label: "Plate-loaded",
                exercise: exercise,
                gym: gym
            )
            machine.goalReps = 8
            machine.goalWeight = 72.5
            machine.goalSetAt = machineGoalSetAt
            machine.goalZone = 3
            machine.goalDuration = 600
            machine.goalIntensity = 13.2
            machine.goalIncline = 0.5
            let entry = Entry(
                reps: 5,
                weight: 57.5,
                duration: 362,
                intensity: 15.1,
                incline: 1.5,
                averageHeartRate: 164,
                peakHeartRate: 171,
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
        #expect(exercise.group?.name == "Treadmills")
        #expect(exercise.goalReps == 5)
        #expect(exercise.goalWeight == 140)
        #expect(exercise.goalSetAt == exerciseGoalSetAt)
        #expect(exercise.unit == "speed")
        #expect(exercise.goalZone == 4)
        #expect(exercise.goalDuration == 360)
        #expect(exercise.goalIntensity == 15.5)
        #expect(exercise.goalIncline == 1)

        let group = try #require(try context.fetch(FetchDescriptor<ExerciseGroup>()).first)
        #expect(group.sortIndex == 3)
        #expect(group.half == "endurance")
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
        #expect(machine.goalReps == 8)
        #expect(machine.goalWeight == 72.5)
        #expect(machine.goalSetAt == machineGoalSetAt)
        #expect(machine.goalZone == 3)
        #expect(machine.goalDuration == 600)
        #expect(machine.goalIntensity == 13.2)
        #expect(machine.goalIncline == 0.5)

        let entry = try #require(try context.fetch(FetchDescriptor<Entry>()).first)
        #expect(entry.reps == 5)
        #expect(entry.weight == 57.5)
        #expect(entry.duration == 362)
        #expect(entry.intensity == 15.1)
        #expect(entry.incline == 1.5)
        #expect(entry.averageHeartRate == 164)
        #expect(entry.peakHeartRate == 171)
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

    @Test("The schema is 3.0.0 and names all five entities")
    func schemaListsFiveEntities() {
        #expect(ChalkSchemaV1.versionIdentifier == Schema.Version(3, 0, 0))
        #expect(ChalkSchemaV1.models.count == 5)
        #expect(ChalkMigrationPlan.schemas.count == 1)
        #expect(ChalkMigrationPlan.stages.isEmpty)
    }
}
