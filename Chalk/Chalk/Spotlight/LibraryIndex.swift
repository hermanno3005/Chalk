import Foundation
import SwiftData

/// One exercise or erg as Spotlight holds it: **the name and nothing else**, so logging
/// never touches the index (SPEC §15.5). The half picks the entity type it is held as,
/// and never changes for an id (invariant 9).
struct IndexedRow: Hashable, Sendable {
    let id: UUID
    let name: String
    let half: Half

    /// Every exercise and erg in the store, both halves.
    static func all(in context: ModelContext) throws -> [IndexedRow] {
        try context.fetch(FetchDescriptor<Exercise>()).map {
            IndexedRow(id: $0.id, name: $0.name, half: $0.half)
        }
    }
}

/// Where the index's writes go: Spotlight in the app, a recorder in the tests.
@MainActor
protocol LibraryIndexSink: AnyObject {
    /// Empties the index of both types, then holds exactly `rows`.
    func rebuild(_ rows: [IndexedRow])
    /// Adds `rows`, or renames them where their id is already held.
    func index(_ rows: [IndexedRow])
    func remove(_ rows: [IndexedRow])
}

/// Keeps Spotlight's copy of the library true (SPEC §15.5), through **one entry point,
/// `sync()`**, rather than a hook at every write.
///
/// It diffs every row's `(id, name, half)` against what it last pushed. Only create,
/// rename, delete and restore change those, so archive, merge, kind change, re-filing and
/// every entry write diff to nothing. A delete is why it diffs rather than reacting to
/// the save itself: `ModelContext.didSave` reports only persistent ids, and a deleted
/// row's UUID can no longer be read through one.
///
/// It runs **after every save of the context it watches** — every write in Chalk ends in
/// `save()` — and not from `LibraryModel.refresh()`, which runs per keystroke and reads
/// one half. The first sync rebuilds the index whole, which is what a launch, and the
/// reopen after a restore or a convert, need.
@MainActor
final class LibraryIndex {
    private let context: ModelContext
    private let sink: any LibraryIndexSink
    /// What the sink holds, by id. `nil` until the first sync, which rebuilds.
    private var pushed: [UUID: IndexedRow]?
    nonisolated(unsafe) private var observer: (any NSObjectProtocol)?

    init(context: ModelContext, sink: any LibraryIndexSink) {
        self.context = context
        self.sink = sink
        // Saves on a context happen on its own actor, and every context this watches
        // is the main one.
        observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: context,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// Pushes what changed since the last sync, or everything on the first.
    func sync() {
        // As elsewhere: v1 has no error state past §3's container failure, and the
        // next save syncs again.
        guard let rows = try? IndexedRow.all(in: context) else { return }
        let current = Dictionary(rows.map { ($0.id, $0) }) { first, _ in first }
        defer { pushed = current }

        guard let pushed else {
            sink.rebuild(rows)
            return
        }
        let changed = rows.filter { pushed[$0.id] != $0 }
        let gone = pushed.values.filter { current[$0.id] == nil }
        if !changed.isEmpty { sink.index(changed) }
        if !gone.isEmpty { sink.remove(Array(gone)) }
    }
}
