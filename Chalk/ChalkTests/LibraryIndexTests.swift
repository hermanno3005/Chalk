import Foundation
import SwiftData
import Testing

@testable import Chalk

/// What Spotlight holds of the library (SPEC §15.5): every exercise and erg by name,
/// kept true by one diff after every save of the context it watches.
@MainActor
@Suite("Library index")
struct LibraryIndexTests {

    @Test("The first sync rebuilds the index with every exercise and erg, each in its half")
    func theFirstSyncRebuildsEverything() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        let rower = fixture.erg("Rower")
        try fixture.save()
        let sink = RecordingIndexSink()

        LibraryIndex(context: fixture.context, sink: sink).sync()

        #expect(sink.calls == [
            .rebuild([
                IndexedRow(id: bench.id, name: "Bench Press", half: .strength),
                IndexedRow(id: rower.id, name: "Rower", half: .endurance),
            ]),
        ])
    }

    @Test("A created exercise or erg is indexed by the save that creates it")
    func aCreateIsIndexed() throws {
        let fixture = try LibraryFixture()
        let indexed = IndexedLibrary(fixture)
        var draft = NewErg(name: "Rower")
        draft.unit = .speed

        let bench = try #require(indexed.library.create(name: "Bench Press", kind: .freeWeight))
        let rower = try #require(indexed.library.create(draft))

        #expect(indexed.sink.calls == [
            .index([IndexedRow(id: bench.id, name: "Bench Press", half: .strength)]),
            .index([IndexedRow(id: rower.id, name: "Rower", half: .endurance)]),
        ])
    }

    @Test("A rename indexes the row again under its new name, on the same id")
    func aRenameIsIndexedAgain() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench")
        let rower = fixture.erg("Rower")
        try fixture.save()
        let indexed = IndexedLibrary(fixture)

        fixture.detailModel(for: bench).rename(to: "Bench Press")
        fixture.ergDetailModel(for: rower).rename(to: "Concept2")

        #expect(indexed.sink.calls == [
            .index([IndexedRow(id: bench.id, name: "Bench Press", half: .strength)]),
            .index([IndexedRow(id: rower.id, name: "Concept2", half: .endurance)]),
        ])
    }

    @Test("A delete removes the row from its own half's type")
    func aDeleteIsRemoved() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        let rower = fixture.erg("Rower")
        try fixture.save()
        let indexed = IndexedLibrary(fixture)

        fixture.detailModel(for: bench).delete()
        fixture.ergDetailModel(for: rower).delete()

        #expect(indexed.sink.calls == [
            .remove([IndexedRow(id: bench.id, name: "Bench Press", half: .strength)]),
            .remove([IndexedRow(id: rower.id, name: "Rower", half: .endurance)]),
        ])
    }

    @Test("A merge, a kind change and a logged entry leave the index alone")
    func whatTheIndexDoesNotHoldWritesNothing() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let loser = fixture.machine(for: legPress, at: gym)
        let sibling = fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        fixture.log(loser, reps: 5, weight: 100)
        try fixture.save()
        let indexed = IndexedLibrary(fixture)

        fixture.gymsModel().merge(loser, into: sibling)
        fixture.detailModel(for: legPress).makeFreeWeight()
        fixture.log(legPress, reps: 8, weight: 90)
        try fixture.save()

        #expect(try fixture.allExercises().map(\.isGymBound) == [false])
        #expect(indexed.sink.calls.isEmpty)
    }
}

/// A library over a fixture's store, with its index already rebuilt and the sink emptied
/// of that rebuild, so a test sees only what came after. Held for the test's length, so
/// the index goes on watching the fixture's context.
@MainActor
private struct IndexedLibrary {
    let library: LibraryModel
    let sink = RecordingIndexSink()
    let index: LibraryIndex

    init(_ fixture: LibraryFixture) {
        library = fixture.libraryModel()
        index = LibraryIndex(context: fixture.context, sink: sink)
        index.sync()
        sink.forget()
    }
}

/// Every write the index pushed, in order, in place of Spotlight.
@MainActor
final class RecordingIndexSink: LibraryIndexSink {
    enum Call: Equatable {
        case rebuild(Set<IndexedRow>)
        case index(Set<IndexedRow>)
        case remove(Set<IndexedRow>)
    }

    private(set) var calls: [Call] = []

    func rebuild(_ rows: [IndexedRow]) { calls.append(.rebuild(Set(rows))) }
    func index(_ rows: [IndexedRow]) { calls.append(.index(Set(rows))) }
    func remove(_ rows: [IndexedRow]) { calls.append(.remove(Set(rows))) }

    func forget() { calls = [] }
}
