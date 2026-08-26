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

    /// A detail model over this store's context. `refreshing` stands in for the library
    /// left behind the screen, which a delete has to put back in step.
    func detailModel(for exercise: Exercise, refreshing library: LibraryModel? = nil) -> ExerciseDetailModel {
        ExerciseDetailModel(exercise: exercise, context: context) { library?.refresh() }
    }

    /// A log sheet over this store's context. `onSave` stands in for the detail screen
    /// behind the sheet, which a write has to put back in step.
    func logSheetModel(for exercise: Exercise, onSave: @escaping () -> Void = {}) -> LogSheetModel {
        LogSheetModel(exercise: exercise, context: context, onSave: onSave)
    }

    /// The same file read through a second container, so what a test asserts is what
    /// reached the disk rather than what is sitting in this context's cache.
    func afterRelaunch() throws -> ModelContext {
        ModelContext(try store.reopened())
    }
}
