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
        #expect(sections[0].tiles.map(\.name) == ["Bench Press"])

        let relaunched = try fixture.afterRelaunch().fetch(FetchDescriptor<Exercise>())
        #expect(relaunched.map(\.name) == ["Bench Press"])
    }

    @Test("A gym machine records the kind, and no machine — that comes with a gym")
    func aGymMachineRecordsOnlyItsKind() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()

        let created = try #require(model.create(name: "Leg Press", kind: .gymBound))

        #expect(created.kind == ExerciseKind.gymBound.rawValue)
        #expect(created.machines?.isEmpty == true)
        #expect(model.content.drawn == "grid Ungrouped[Leg Press]")
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

    // MARK: - The resume card

    @Test("A store with no entries shows no resume card")
    func aStoreWithNoEntriesHasNoResumeCard() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.create(name: "Squat", kind: .freeWeight)

        #expect(model.resume == nil)
    }

    @Test("The resume card and the tile subtitle move on the log that made them")
    func loggingMovesTheResumeCardAndTheSubtitle() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let squat = try #require(model.create(name: "Squat", kind: .freeWeight))
        try #require(model.create(name: "Bench Press", kind: .freeWeight))
        #expect(model.content.drawn == "grid Ungrouped[Bench Press, Squat]")

        let sheet = model.logSheet(for: squat)
        sheet.advance()
        sheet.type(.digit(6))
        sheet.type(.digit(0))
        sheet.save()

        let resume = try #require(model.resume)
        #expect(resume.exercise === squat)
        #expect(resume.lastEntry.text() == "5 × 60 kg · today")
        // The tile that was logged has both the subtitle and the front of its section.
        guard case .grid(let sections) = model.content else {
            Issue.record("Expected the grid, got \(model.content.drawn)")
            return
        }
        #expect(sections[0].tiles.map(\.name) == ["Squat", "Bench Press"])
        #expect(sections[0].tiles[0].lastEntry?.text() == "5 × 60 kg · today")
        #expect(sections[0].tiles[1].lastEntry == nil)
    }

    @Test("An entry logged from the detail screen moves the library behind it")
    func loggingFromTheDetailScreenMovesTheLibrary() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let squat = try #require(model.create(name: "Squat", kind: .freeWeight))
        try #require(model.create(name: "Bench Press", kind: .freeWeight))

        // Held for the length of the test as the pushed screen holds it in `@State`:
        // the sheet keeps only a weak reference back to it.
        let detail = model.detail(for: squat)
        let sheet = detail.logSheet {}
        sheet.advance()
        sheet.type(.digit(6))
        sheet.type(.digit(0))
        sheet.save()

        // The commoner logging path of the two: the card, the subtitle and the order
        // behind the back button all have to have moved with it.
        #expect(detail.entryCount == 1)
        #expect(model.resume?.exercise === squat)
        #expect(model.resume?.lastEntry.text() == "5 × 60 kg · today")
        #expect(model.content.drawn == "grid Ungrouped[Squat, Bench Press]")
    }

    @Test("Log again seeds the sheet from the entry the card shows")
    func logAgainSeedsFromTheCardsEntry() throws {
        let fixture = try LibraryFixture()
        let squat = fixture.exercise("Squat")
        fixture.log(squat, reps: 8, weight: 52.5, on: .now)
        try fixture.save()
        let model = fixture.libraryModel()

        let resume = try #require(model.resume)
        let sheet = model.logSheet(for: resume.exercise)

        #expect(sheet.reps == 8)
        #expect(sheet.weight == 52.5)
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
        #expect(first[0].tiles[0].exercise === second[0].tiles[0].exercise)
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

    // MARK: - Assignment

    @Test("A tile assigned to a group moves section and survives relaunch")
    func anAssignedTileMovesSection() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let squat = try #require(model.create(name: "Squat", kind: .freeWeight))
        let compound = try #require(model.groups.groups.first { $0.name == "Compound" })

        model.assign(squat, to: compound)

        #expect(model.content.drawn == "grid Compound[Squat]")
        let relaunched = try fixture.afterRelaunch().fetch(FetchDescriptor<Exercise>())
        #expect(relaunched.first?.group?.name == "Compound")
    }

    @Test("Assigning to no group returns a tile to Ungrouped")
    func assigningToNoGroupReturnsToUngrouped() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let squat = try #require(model.create(name: "Squat", kind: .freeWeight))
        let compound = try #require(model.groups.groups.first { $0.name == "Compound" })
        model.assign(squat, to: compound)

        model.assign(squat, to: nil)

        #expect(model.content.drawn == "grid Ungrouped[Squat]")
    }

    @Test("A drop files the tile whose id it carried")
    func aDropFilesTheTileItCarried() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let squat = try #require(model.create(name: "Squat", kind: .freeWeight))
        model.create(name: "Curl", kind: .freeWeight)
        let compound = try #require(model.groups.groups.first { $0.name == "Compound" })

        #expect(model.assign(exerciseWithID: squat.id, to: compound))

        #expect(model.content.drawn == "grid Compound[Squat] Ungrouped[Curl]")
    }

    @Test("A drop carrying an id the library does not hold files nothing")
    func aDropOfAnUnknownIDFilesNothing() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.create(name: "Squat", kind: .freeWeight)
        let compound = try #require(model.groups.groups.first { $0.name == "Compound" })

        // A drag can carry text from anywhere; a drop that resolves to nothing is
        // refused rather than guessed at.
        #expect(model.assign(exerciseWithID: UUID(), to: compound) == false)
        #expect(model.content.drawn == "grid Ungrouped[Squat]")
    }

    // MARK: - Editing groups behind the grid

    @Test("Reordering groups reorders the grid's sections")
    func reorderingGroupsReordersTheGrid() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let squat = try #require(model.create(name: "Squat", kind: .freeWeight))
        let curl = try #require(model.create(name: "Leg Curl", kind: .freeWeight))
        let compound = try #require(model.groups.groups.first { $0.name == "Compound" })
        let legs = try #require(model.groups.groups.first { $0.name == "Legs" })
        model.assign(squat, to: compound)
        model.assign(curl, to: legs)
        #expect(model.content.drawn == "grid Compound[Squat] Legs[Leg Curl]")

        // Legs is second of the five seeded groups; moving it to the front is the
        // section order on the library screen changing (SPEC §7.2).
        model.groups.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        #expect(model.content.drawn == "grid Legs[Leg Curl] Compound[Squat]")
    }

    @Test("Deleting a group drops its tiles into Ungrouped on the grid")
    func deletingAGroupDropsItsTilesIntoUngrouped() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let squat = try #require(model.create(name: "Squat", kind: .freeWeight))
        let compound = try #require(model.groups.groups.first { $0.name == "Compound" })
        model.assign(squat, to: compound)

        model.groups.delete(compound)

        #expect(model.content.drawn == "grid Ungrouped[Squat]")
    }

    @Test("A group renamed behind the grid retitles its section")
    func aRenamedGroupRetitlesItsSection() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let squat = try #require(model.create(name: "Squat", kind: .freeWeight))
        let compound = try #require(model.groups.groups.first { $0.name == "Compound" })
        model.assign(squat, to: compound)

        model.groups.rename(compound, to: "Big lifts")

        #expect(model.content.drawn == "grid Big lifts[Squat]")
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
            (["grid"] + sections.map { "\($0.title)[\($0.tiles.map(\.name).joined(separator: ", "))]" })
                .joined(separator: " ")
        case .searching(let matches, let createSuggestion):
            (["searching", "[\(matches.map(\.name).joined(separator: ", "))]"]
                + (createSuggestion.map { ["create \"\($0)\""] } ?? []))
                .joined(separator: " ")
        }
    }
}
