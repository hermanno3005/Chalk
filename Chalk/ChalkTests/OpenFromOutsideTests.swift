import Foundation
import SwiftData
import Testing

@testable import Chalk

/// A Spotlight result or an Open shortcut, opening an exercise or erg on its detail
/// screen in its own half (SPEC §15.5), and what it does over unfinished work: what a
/// swipe-down would do.
@Suite("Opening from outside Chalk")
struct OpenFromOutsideTests {

    @Test("A result opens on its detail screen, in its own half, with the search ended")
    func aResultOpensInItsOwnHalf() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        let rower = fixture.erg("Rower")
        try fixture.save()
        let library = fixture.libraryModel()
        library.path = [bench]
        library.search("Ben")

        #expect(library.open(exerciseWithID: rower.id))

        #expect(library.half == .endurance)
        #expect(library.path.map(\.name) == ["Rower"])
        #expect(library.query.isEmpty)
        #expect(library.closings == 1)
    }

    @Test("A result for the detail screen already on top changes nothing")
    func aResultForTheTopIsANoOp() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower")
        try fixture.save()
        let library = fixture.libraryModel()
        library.show(.endurance)
        library.path = [rower]
        let grid = fixture.lapListModel(for: rower)
        grid.addRow()
        library.presented(grid)

        #expect(library.open(exerciseWithID: rower.id))

        #expect(library.path.map(\.name) == ["Rower"])
        #expect(library.closings == 0)
        #expect(!grid.isHoldingAnOpen)
    }

    @Test("An untouched grid closes silently, as a swipe-down would")
    func anUntouchedGridClosesSilently() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        let rower = fixture.erg("Rower")
        try fixture.save()
        let library = fixture.libraryModel()
        library.show(.endurance)
        library.path = [rower]
        library.presented(fixture.lapListModel(for: rower))

        library.open(exerciseWithID: bench.id)

        #expect(library.path.map(\.name) == ["Bench Press"])
        #expect(library.closings == 1)
    }

    @Test("A touched grid asks in its own words, and Discard opens the result")
    func aTouchedGridHoldsTheOpenUntilDiscard() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        let rower = fixture.erg("Rower")
        try fixture.save()
        let library = fixture.libraryModel()
        library.show(.endurance)
        library.path = [rower]
        let grid = fixture.lapListModel(for: rower)
        grid.addRow()
        library.presented(grid)

        library.open(exerciseWithID: bench.id)

        #expect(grid.isHoldingAnOpen)
        #expect(grid.discardConfirmation == "Discard 2 entries?")
        #expect(library.path.map(\.name) == ["Rower"])
        #expect(library.closings == 0)

        grid.discardForHeldOpen()

        #expect(!grid.isHoldingAnOpen)
        #expect(library.half == .strength)
        #expect(library.path.map(\.name) == ["Bench Press"])
        #expect(library.closings == 1)
    }

    @Test("Keep editing drops the result, and nothing fires when the grid closes")
    func keepEditingDropsTheOpen() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        let rower = fixture.erg("Rower")
        try fixture.save()
        let library = fixture.libraryModel()
        library.show(.endurance)
        let grid = fixture.lapListModel(for: rower)
        grid.addRow()
        library.presented(grid)
        library.open(exerciseWithID: bench.id)

        grid.keepEditing()
        library.dismissed(grid)
        grid.discardForHeldOpen()

        #expect(!grid.isHoldingAnOpen)
        #expect(library.half == .endurance)
        #expect(library.path.isEmpty)
        #expect(library.closings == 0)
    }

    @Test("A grid that has closed no longer holds anything open")
    func aClosedGridHoldsNothing() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        let rower = fixture.erg("Rower")
        try fixture.save()
        let library = fixture.libraryModel()
        let grid = fixture.lapListModel(for: rower)
        grid.addRow()
        library.presented(grid)
        library.dismissed(grid)

        library.open(exerciseWithID: bench.id)

        #expect(!grid.isHoldingAnOpen)
        #expect(library.path.map(\.name) == ["Bench Press"])
    }

    @Test("An id the library no longer holds opens nothing")
    func aStaleResultOpensNothing() throws {
        let fixture = try LibraryFixture()
        let library = fixture.libraryModel()

        #expect(!library.open(exerciseWithID: UUID()))
        #expect(library.path.isEmpty)
        #expect(library.closings == 0)
    }
}
