import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The library screen's states and its one mutation (SPEC §7.1–7.3, §9's state table).
///
/// `content` is a cached value refreshed on mutation, never a computed property — a sort
/// behind `var body` re-ran once per group per frame of a drag (SPEC §7.2, hazard 3).
@Suite("Library model")
struct LibraryModelTests {

    // MARK: - States

    @Test("A store with no exercises is the empty state")
    func anEmptyStoreIsTheEmptyState() throws {
        let fixture = try LibraryFixture()

        #expect(fixture.libraryModel().content.drawn == "empty")
    }

    @Test("Seeded groups alone do not make the library non-empty")
    func seededGroupsDoNotFillTheLibrary() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()

        #expect(try fixture.allGroups().count == 5)
        #expect(model.content.drawn == "empty")
    }

    @Test("A created free-weight exercise lands in Ungrouped and survives relaunch")
    func aCreatedExerciseLandsInUngroupedAndPersists() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()

        let created = try #require(model.create(name: "Bench Press", kind: .freeWeight))

        #expect(created.group == nil)
        #expect(created.kind == ExerciseKind.freeWeight.rawValue)
        guard case .grid(let sections) = model.content else {
            Issue.record("Expected the grid, got \(model.content.drawn)")
            return
        }
        #expect(sections.map(\.title) == ["Ungrouped"])
        #expect(sections[0].exercises.map(\.name) == ["Bench Press"])

        let relaunched = try fixture.afterRelaunch().fetch(FetchDescriptor<Exercise>())
        #expect(relaunched.map(\.name) == ["Bench Press"])
    }

    @Test("A name that is blank once trimmed creates nothing")
    func aBlankNameCreatesNothing() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()

        #expect(model.create(name: "   ", kind: .freeWeight) == nil)
        #expect(model.content.drawn == "empty")
    }

    @Test("A created name is trimmed")
    func aCreatedNameIsTrimmed() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()

        #expect(model.create(name: "  Front Squat ", kind: .freeWeight)?.name == "Front Squat")
    }

    // MARK: - Search

    @Test("Searching filters the library to its matches")
    func searchingFiltersToMatches() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.create(name: "Bench Press", kind: .freeWeight)
        model.create(name: "Squat", kind: .freeWeight)

        model.search("ben")

        #expect(model.content.drawn == "searching [Bench Press]")
    }

    @Test("A query matching nothing offers Create it as the last result")
    func aQueryMatchingNothingOffersCreateIt() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.create(name: "Bench Press", kind: .freeWeight)

        model.search("Hip Thrust")

        #expect(model.content.drawn == "searching [] create \"Hip Thrust\"")
    }

    @Test("Create it creates the typed name and returns to the grid")
    func createItCreatesAndReturnsToTheGrid() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.search("Hip Thrust")

        let created = try #require(model.create(name: "Hip Thrust", kind: .freeWeight))

        #expect(created.name == "Hip Thrust")
        #expect(model.query.isEmpty)
        #expect(model.content.drawn == "grid Ungrouped[Hip Thrust]")
    }

    @Test("Clearing the search returns to the grid")
    func clearingTheSearchReturnsToTheGrid() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.create(name: "Squat", kind: .freeWeight)
        model.search("zzz")

        model.search("")

        #expect(model.content.drawn == "grid Ungrouped[Squat]")
    }

    @Test("An empty store searched still offers Create it rather than the empty state")
    func anEmptyStoreSearchedOffersCreateIt() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()

        model.search("Squat")

        #expect(model.content.drawn == "searching [] create \"Squat\"")
    }

    // MARK: - Caching

    @Test("The grid is cached: reading content twice does not re-derive it")
    func theGridIsCached() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.create(name: "Squat", kind: .freeWeight)

        guard case .grid(let first) = model.content, case .grid(let second) = model.content else {
            Issue.record("Expected the grid, got \(model.content.drawn)")
            return
        }
        #expect(first[0].id == second[0].id)
        #expect(first[0].exercises[0] === second[0].exercises[0])
    }

    @Test("A group assignment made outside the model shows after a refresh")
    func aRefreshPicksUpOutsideMutations() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let squat = try #require(model.create(name: "Squat", kind: .freeWeight))
        let legs = try #require(try fixture.allGroups().first { $0.name == "Legs" })

        squat.group = legs
        try fixture.save()
        #expect(model.content.drawn == "grid Ungrouped[Squat]")

        model.refresh()

        #expect(model.content.drawn == "grid Legs[Squat]")
    }
}

// MARK: - Reading a Content

/// Sections hold live models, so a `Content` is asserted by the shape it would draw:
/// `grid Compound[Squat] Ungrouped[Curl]`, `searching [Bench Press] create "Hip"`.
extension LibraryModel.Content {
    var drawn: String {
        switch self {
        case .empty:
            "empty"
        case .grid(let sections):
            (["grid"] + sections.map { "\($0.title)[\($0.exercises.map(\.name).joined(separator: ", "))]" })
                .joined(separator: " ")
        case .searching(let matches, let createSuggestion):
            (["searching", "[\(matches.map(\.name).joined(separator: ", "))]"]
                + (createSuggestion.map { ["create \"\($0)\""] } ?? []))
                .joined(separator: " ")
        }
    }
}
