import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The delete rules from SPEC §3. Gym is the one that matters: cascading from a gym
/// would reach every entry ever logged there.
@Suite("Delete rules")
struct DeleteRuleTests {

    @Test("Deleting an exercise cascades to its entries and its machines")
    func exerciseCascades() throws {
        let store = try TemporaryStore()
        let context = ModelContext(store.container)

        let gym = Gym(name: "Fitness X")
        let exercise = Exercise(name: "Chest Press", kind: .gymBound)
        let machine = Machine(label: "Plate-loaded", exercise: exercise, gym: gym)
        let onMachine = Entry(reps: 5, weight: 60, exercise: exercise, machine: machine)
        let offMachine = Entry(reps: 3, weight: 70, exercise: exercise)
        try store.insertAll([gym, exercise, machine, onMachine, offMachine], into: context)

        context.delete(exercise)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Machine>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Gym>()) == 1)
    }

    @Test("Deleting a machine cascades to that machine's entries only")
    func machineCascades() throws {
        let store = try TemporaryStore()
        let context = ModelContext(store.container)

        let exercise = Exercise(name: "Chest Press", kind: .gymBound)
        let doomed = Machine(label: "Old", exercise: exercise)
        let sibling = Machine(label: "New", exercise: exercise)
        let doomedEntry = Entry(reps: 5, weight: 60, exercise: exercise, machine: doomed)
        let survivor = Entry(reps: 5, weight: 65, exercise: exercise, machine: sibling)
        try store.insertAll([exercise, doomed, sibling, doomedEntry, survivor], into: context)

        context.delete(doomed)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Entry>()).map(\.weight) == [65])
        #expect(try context.fetch(FetchDescriptor<Machine>()).map(\.label) == ["New"])
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }

    @Test("Deleting a group only nullifies — its exercises fall back to Ungrouped")
    func groupNullifies() throws {
        let store = try TemporaryStore()
        let context = ModelContext(store.container)

        let group = ExerciseGroup(name: "Push")
        let exercise = Exercise(name: "Bench Press", group: group)
        let entry = Entry(reps: 5, weight: 80, exercise: exercise)
        try store.insertAll([group, exercise, entry], into: context)

        context.delete(group)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<ExerciseGroup>()) == 0)
        let survivor = try #require(try context.fetch(FetchDescriptor<Exercise>()).first)
        #expect(survivor.name == "Bench Press")
        #expect(survivor.group == nil)
        #expect(try context.fetchCount(FetchDescriptor<Entry>()) == 1)
    }

    @Test("Deleting a gym only nullifies — every machine and entry survives")
    func gymNullifies() throws {
        let store = try TemporaryStore()
        let context = ModelContext(store.container)

        let gym = Gym(name: "Fitness X")
        let exercise = Exercise(name: "Chest Press", kind: .gymBound)
        let machine = Machine(label: "Plate-loaded", exercise: exercise, gym: gym)
        let entry = Entry(reps: 5, weight: 60, exercise: exercise, machine: machine)
        try store.insertAll([gym, exercise, machine, entry], into: context)

        context.delete(gym)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Gym>()) == 0)
        let survivor = try #require(try context.fetch(FetchDescriptor<Machine>()).first)
        #expect(survivor.label == "Plate-loaded")
        #expect(survivor.gym == nil)
        #expect(survivor.exercise?.name == "Chest Press")
        #expect(try context.fetch(FetchDescriptor<Entry>()).map(\.weight) == [60])
    }
}
