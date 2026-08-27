import Foundation
import SwiftData
import Testing

@testable import Chalk

/// A real on-disk store plus a `UserDefaults` suite of its own, so a test that seeds the
/// suggested groups cannot see — or leave behind — another test's seed flag.
final class LibraryFixture {
    let store: TemporaryStore
    let context: ModelContext
    let defaults: UserDefaults
    private let suiteName: String

    init() throws {
        store = try TemporaryStore()
        context = ModelContext(store.container)
        suiteName = "chalk-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @discardableResult
    func exercise(
        _ name: String,
        kind: ExerciseKind = .freeWeight,
        group: ExerciseGroup? = nil
    ) -> Exercise {
        let exercise = Exercise(name: name, kind: kind, group: group)
        context.insert(exercise)
        return exercise
    }

    /// A gym on this store. Gyms are held explicitly, never derived from the machines
    /// that happen to exist (SPEC §3).
    @discardableResult
    func gym(_ name: String, isArchived: Bool = false) -> Gym {
        let gym = Gym(name: name, isArchived: isArchived)
        context.insert(gym)
        return gym
    }

    /// A machine for one exercise at one gym — a gym-bound exercise's unit of scope.
    @discardableResult
    func machine(
        for exercise: Exercise,
        at gym: Gym?,
        manufacturer: String? = nil,
        label: String? = nil
    ) -> Machine {
        let machine = Machine(
            manufacturer: manufacturer,
            label: label,
            exercise: exercise,
            gym: gym
        )
        context.insert(machine)
        return machine
    }

    @discardableResult
    func group(_ name: String, sortIndex: Int) -> ExerciseGroup {
        let group = ExerciseGroup(name: name, sortIndex: sortIndex)
        context.insert(group)
        return group
    }

    func log(_ exercise: Exercise, on date: Date) {
        log(exercise, reps: 8, weight: 52.5, on: date)
    }

    func log(_ exercise: Exercise, reps: Int, weight: Double, on date: Date = .now) {
        context.insert(Entry(reps: reps, weight: weight, date: date, exercise: exercise))
    }

    /// An entry on one machine. `entry.machine?.exercise == entry.exercise` is the
    /// invariant every write holds (SPEC §3), so the exercise comes off the machine.
    func log(_ machine: Machine, reps: Int, weight: Double, on date: Date = .now) {
        context.insert(Entry(
            reps: reps,
            weight: weight,
            date: date,
            exercise: machine.exercise,
            machine: machine
        ))
    }

    func save() throws {
        try context.save()
    }

    func allExercises() throws -> [Exercise] {
        try context.fetch(FetchDescriptor<Exercise>())
    }

    func allGroups() throws -> [ExerciseGroup] {
        try context.fetch(FetchDescriptor<ExerciseGroup>())
    }

    /// A model over this store's context, seeded against this fixture's own defaults.
    func libraryModel() -> LibraryModel {
        LibraryModel(context: context, defaults: defaults)
    }

    /// The gyms model over this store's context, holding the current gym in this
    /// fixture's own defaults suite rather than the running app's.
    func gymsModel() -> GymsModel {
        GymsModel(context: context, defaults: defaults)
    }

    /// The groups model over this store's context. It seeds nothing — the suggestion is
    /// `LibraryModel`'s to plant (SPEC §7.2) — so a test here arranges the groups it
    /// wants and sees no others.
    func groupsModel() -> GroupsModel {
        GroupsModel(context: context)
    }

    /// A detail model over this store's context. `refreshing` stands in for the library
    /// left behind the screen, which a delete has to put back in step.
    func detailModel(
        for exercise: Exercise,
        gyms: GymsModel? = nil,
        refreshing library: LibraryModel? = nil
    ) -> ExerciseDetailModel {
        ExerciseDetailModel(
            exercise: exercise,
            context: context,
            gyms: gyms ?? gymsModel()
        ) { library?.refresh() }
    }

    /// A log sheet over this store's context. `onSave` stands in for the detail screen
    /// behind the sheet, which a write has to put back in step. `editing` is the entry
    /// being corrected, which is the whole difference between the sheet's two
    /// presentations (SPEC §6.6).
    func logSheetModel(
        for exercise: Exercise,
        on machine: Machine? = nil,
        editing: Entry? = nil,
        gyms: GymsModel? = nil,
        onSave: @escaping () -> Void = {}
    ) -> LogSheetModel {
        LogSheetModel(
            exercise: exercise,
            machine: machine,
            editing: editing,
            context: context,
            gyms: gyms ?? gymsModel(),
            onSave: onSave
        )
    }

    /// A history sheet over this store's context, at one rep count. `onChange` stands
    /// in for the screens behind it — the detail curve and the library — which an edit
    /// or a delete has to put back in step.
    func historySheetModel(
        for exercise: Exercise,
        on machine: Machine? = nil,
        atLeast reps: Int,
        gyms: GymsModel? = nil,
        onChange: @escaping () -> Void = {}
    ) -> HistorySheetModel {
        HistorySheetModel(
            exercise: exercise,
            machine: machine,
            atLeast: reps,
            context: context,
            gyms: gyms ?? gymsModel(),
            onChange: onChange
        )
    }

    /// The same file read through a second container, so what a test asserts is what
    /// reached the disk rather than what is sitting in this context's cache.
    func afterRelaunch() throws -> ModelContext {
        ModelContext(try store.reopened())
    }
}

extension Date {
    /// A date `days` back, for seeding history that has to come out in a known order.
    static func days(ago days: Int) -> Date {
        .now.addingTimeInterval(-Double(days) * 86_400)
    }
}
