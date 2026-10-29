import CoreSpotlight

/// Spotlight's side of `LibraryIndex`: Chalk's named index, holding each row as an
/// `ExerciseEntity` or an `ErgEntity` by its half (SPEC §15.5), and the App Shortcuts'
/// suggestions, which follow the same rows.
///
/// **Its writes are chained**, each starting when the one before it ends: an index may
/// be modified from only one task at a time, and an actor alone would let a rename's
/// write interleave with the next delete at each `await`.
@MainActor
final class SpotlightIndex: LibraryIndexSink {
    private var last: Task<Void, Never>?

    func rebuild(_ rows: [IndexedRow]) {
        chain {
            let index = Self.named()
            try await index.deleteAppEntities(ofType: ExerciseEntity.self)
            try await index.deleteAppEntities(ofType: ErgEntity.self)
            try await Self.index(rows, into: index)
        }
    }

    func index(_ rows: [IndexedRow]) {
        chain { try await Self.index(rows, into: Self.named()) }
    }

    func remove(_ rows: [IndexedRow]) {
        chain {
            let index = Self.named()
            let (exercises, ergs) = Self.entities(rows)
            if !exercises.isEmpty {
                try await index.deleteAppEntities(identifiedBy: exercises.map(\.id), ofType: ExerciseEntity.self)
            }
            if !ergs.isEmpty {
                try await index.deleteAppEntities(identifiedBy: ergs.map(\.id), ofType: ErgEntity.self)
            }
        }
    }

    /// Chalk's own index rather than the default one, as Apple asks. Made per write
    /// rather than held: every handle by this name is the same index, and one held on
    /// the main actor couldn't be handed to the write running off it.
    nonisolated private static func named() -> CSSearchableIndex {
        CSSearchableIndex(name: "Library")
    }

    nonisolated private static func index(_ rows: [IndexedRow], into index: CSSearchableIndex) async throws {
        let (exercises, ergs) = entities(rows)
        if !exercises.isEmpty { try await index.indexAppEntities(exercises) }
        if !ergs.isEmpty { try await index.indexAppEntities(ergs) }
    }

    /// Each row as the entity its half is held as.
    nonisolated private static func entities(_ rows: [IndexedRow]) -> ([ExerciseEntity], [ErgEntity]) {
        (
            rows.filter { $0.half == .strength }.map { ExerciseEntity(id: $0.id, name: $0.name) },
            rows.filter { $0.half == .endurance }.map { ErgEntity(id: $0.id, name: $0.name) }
        )
    }

    private func chain(_ write: @escaping @Sendable () async throws -> Void) {
        let previous = last
        last = Task {
            await previous?.value
            // Nothing to report and nothing to retry: the next launch rebuilds the index
            // whole, which mends whatever a failed write left.
            try? await write()
            // The App Shortcuts' tiles and phrases follow the same rows, so they are asked
            // to re-read their suggestions after every write, the launch's rebuild
            // included (SPEC §15.5).
            ChalkShortcuts.updateAppShortcutParameters()
        }
    }
}
