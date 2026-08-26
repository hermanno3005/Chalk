import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The library's ordering and its search (SPEC §7.1). These run against a real store
/// because the ordering reads relationships — `Exercise.group` and `Entry.date` — and a
/// detached model graph is not what the screen will be handed.
@Suite("Library ordering")
struct LibraryOrderingTests {

    // MARK: - Sections

    @Test("Sections follow the user's sortIndex, with Ungrouped last")
    func sectionsFollowSortIndexWithUngroupedLast() throws {
        let fixture = try LibraryFixture()
        let push = fixture.group("Push", sortIndex: 1)
        let compound = fixture.group("Compound", sortIndex: 0)
        fixture.exercise("Overhead Press", group: push)
        fixture.exercise("Squat", group: compound)
        fixture.exercise("Calf Raise")
        try fixture.save()

        let sections = LibraryOrdering.sections(
            exercises: try fixture.allExercises(),
            groups: try fixture.allGroups()
        )

        #expect(sections.map(\.title) == ["Compound", "Push", "Ungrouped"])
        #expect(sections.last?.isUngrouped == true)
        #expect(sections[0].exercises.map(\.name) == ["Squat"])
    }

    @Test("A group holding nothing has no section")
    func emptyGroupsAreNotSections() throws {
        let fixture = try LibraryFixture()
        fixture.group("Legs", sortIndex: 0)
        fixture.exercise("Curl")
        try fixture.save()

        let sections = LibraryOrdering.sections(
            exercises: try fixture.allExercises(),
            groups: try fixture.allGroups()
        )

        #expect(sections.map(\.title) == ["Ungrouped"])
    }

    @Test("An empty library has no sections at all")
    func anEmptyLibraryHasNoSections() throws {
        let fixture = try LibraryFixture()
        fixture.group("Legs", sortIndex: 0)
        try fixture.save()

        #expect(LibraryOrdering.sections(
            exercises: try fixture.allExercises(),
            groups: try fixture.allGroups()
        ).isEmpty)
    }

    @Test("Tiles within a section order by recency, never-logged last and by name")
    func tilesOrderByRecency() throws {
        let fixture = try LibraryFixture()
        let today = Date.now
        fixture.log(fixture.exercise("Squat"), on: today.addingTimeInterval(-86_400))
        fixture.log(fixture.exercise("Bench Press"), on: today)
        fixture.exercise("Zercher Squat")
        fixture.exercise("Ab Wheel")
        try fixture.save()

        let sections = LibraryOrdering.sections(
            exercises: try fixture.allExercises(),
            groups: try fixture.allGroups()
        )

        #expect(sections[0].exercises.map(\.name)
            == ["Bench Press", "Squat", "Ab Wheel", "Zercher Squat"])
    }

    // MARK: - Search

    @Test("Search matches anywhere in the name, ignoring case and diacritics")
    func searchIgnoresCaseAndDiacritics() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Bulgarian Split Squat")
        fixture.exercise("Bench Press")
        fixture.exercise("Curl")
        try fixture.save()
        let exercises = try fixture.allExercises()

        #expect(LibraryOrdering.matches(exercises, query: "SQUAT").map(\.name)
            == ["Bulgarian Split Squat"])
        #expect(LibraryOrdering.matches(exercises, query: "prèss").map(\.name)
            == ["Bench Press"])
        #expect(LibraryOrdering.matches(exercises, query: "  ").count == 3)
    }

    @Test("A query nothing matches yields nothing")
    func aQueryNothingMatchesYieldsNothing() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Bench Press")
        try fixture.save()

        #expect(LibraryOrdering.matches(try fixture.allExercises(), query: "zzz").isEmpty)
    }
}
