import AppIntents
import Foundation

/// An exercise as Spotlight and Shortcuts hold it (SPEC §15.5): its id and its name,
/// and nothing a log would change. A plain value that refers to the row, never the
/// `@Model` itself, which isn't `Sendable`.
///
/// **Two entity types rather than one** though the model is one `Exercise` (ADR-0008):
/// each half keeps its own word, so Shortcuts says *Open Exercise* and *Open Erg*, and
/// never calls an erg an exercise.
struct ExerciseEntity: IndexedEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Exercise" }
    static var defaultQuery: ExerciseQuery { ExerciseQuery() }

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

/// An erg as Spotlight and Shortcuts hold it, as `ExerciseEntity` is an exercise.
struct ErgEntity: IndexedEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Erg" }
    static var defaultQuery: ErgQuery { ErgQuery() }

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

/// Every exercise, for a Shortcuts picker and for resolving a Spotlight result. A
/// library holds tens of rows, so the system filters the whole list itself.
struct ExerciseQuery: EnumerableEntityQuery {
    @Dependency private var router: LibraryRouter

    func allEntities() async throws -> [ExerciseEntity] {
        try await router.rows(in: .strength).map { ExerciseEntity(id: $0.id, name: $0.name) }
    }

    /// The exercises the App Shortcuts offer a tile and a phrase for: every one, unless
    /// Apple's phrase cap bites (`LibraryRouter.suggested(in:)`).
    func suggestedEntities() async throws -> [ExerciseEntity] {
        try await router.suggested(in: .strength).map { ExerciseEntity(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [UUID]) async throws -> [ExerciseEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }
}

/// Every erg, as `ExerciseQuery` lists every exercise.
struct ErgQuery: EnumerableEntityQuery {
    @Dependency private var router: LibraryRouter

    func allEntities() async throws -> [ErgEntity] {
        try await router.rows(in: .endurance).map { ErgEntity(id: $0.id, name: $0.name) }
    }

    /// The ergs the App Shortcuts offer a tile and a phrase for, as `ExerciseQuery`'s.
    func suggestedEntities() async throws -> [ErgEntity] {
        try await router.suggested(in: .endurance).map { ErgEntity(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [UUID]) async throws -> [ErgEntity] {
        try await allEntities().filter { identifiers.contains($0.id) }
    }
}
