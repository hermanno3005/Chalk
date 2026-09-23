import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The library's derived shape — its resume card, its sections and its search (SPEC §7.1).
/// These run against a real store because the derivation reads relationships —
/// `Exercise.group` and `Entry.date` — and a detached model graph is not what the screen
/// will be handed.
@Suite("Library layout")
struct LibraryLayoutTests {

    private func layout(_ fixture: LibraryFixture) throws -> LibraryLayout {
        LibraryLayout(
            exercises: try fixture.allExercises(),
            groups: try fixture.allGroups()
        )
    }

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

        let sections = try layout(fixture).sections

        #expect(sections.map(\.title) == ["Compound", "Push", "Ungrouped"])
        #expect(sections.last?.isUngrouped == true)
        #expect(sections[0].tiles.map(\.name) == ["Squat"])
    }

    @Test("A group holding nothing has no section")
    func emptyGroupsAreNotSections() throws {
        let fixture = try LibraryFixture()
        fixture.group("Legs", sortIndex: 0)
        fixture.exercise("Curl")
        try fixture.save()

        #expect(try layout(fixture).sections.map(\.title) == ["Ungrouped"])
    }

    @Test("An empty library has no sections at all")
    func anEmptyLibraryHasNoSections() throws {
        let fixture = try LibraryFixture()
        fixture.group("Legs", sortIndex: 0)
        try fixture.save()

        #expect(try layout(fixture).sections.isEmpty)
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

        let sections = try layout(fixture).sections

        #expect(sections[0].tiles.map(\.name)
            == ["Bench Press", "Squat", "Ab Wheel", "Zercher Squat"])
    }

    @Test("Recency is each exercise's own most recent entry, not its first")
    func recencyReadsTheMostRecentEntry() throws {
        let fixture = try LibraryFixture()
        let now = Date.now
        let squat = fixture.exercise("Squat")
        let bench = fixture.exercise("Bench Press")
        fixture.log(squat, on: now.addingTimeInterval(-864_000))
        fixture.log(squat, on: now)
        fixture.log(bench, on: now.addingTimeInterval(-86_400))
        try fixture.save()

        #expect(try layout(fixture).sections[0].tiles.map(\.name) == ["Squat", "Bench Press"])
    }

    // MARK: - Subtitles

    @Test("A tile carries what you last did for it; an unlogged exercise carries nothing")
    func tilesCarryTheirLastEntry() throws {
        let fixture = try LibraryFixture()
        let squat = fixture.exercise("Squat")
        let now = Date.now
        fixture.log(squat, reps: 5, weight: 100, on: now.addingTimeInterval(-86_400))
        fixture.log(squat, reps: 8, weight: 52.5, on: now)
        fixture.exercise("Ab Wheel")
        try fixture.save()

        let tiles = try layout(fixture).tiles

        #expect(tiles[0].lastEntry?.text(asOf: now) == "8 × \(52.5.kilogramsText) kg · today")
        #expect(tiles[1].lastEntry == nil)
    }

    @Test("A zeroed row is not what you last did")
    func aZeroedRowIsNotASubtitle() throws {
        let fixture = try LibraryFixture()
        let squat = fixture.exercise("Squat")
        fixture.log(squat, reps: 0, weight: 0, on: .now)
        try fixture.save()

        #expect(try layout(fixture).tiles[0].lastEntry == nil)
    }

    // MARK: - The resume card

    @Test("The resume card is the most recent entry across every exercise")
    func theResumeCardIsTheLatestEntryAnywhere() throws {
        let fixture = try LibraryFixture()
        let now = Date.now
        let squat = fixture.exercise("Squat")
        fixture.log(squat, reps: 5, weight: 100, on: now.addingTimeInterval(-86_400))
        fixture.log(fixture.exercise("Bench Press"), reps: 8, weight: 52.5, on: now)
        try fixture.save()

        let resume = try #require(try layout(fixture).resume)

        #expect(resume.exercise.name == "Bench Press")
        #expect(resume.lastEntry.text(asOf: now) == "8 × \(52.5.kilogramsText) kg · today")
    }

    @Test("A library with nothing logged has no resume card")
    func nothingLoggedHasNoResumeCard() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Squat")
        try fixture.save()

        #expect(try layout(fixture).resume == nil)
    }

    // MARK: - The resume card's ring

    @Test("A free-weight goal rings the resume card, filled from where you stood when it was set")
    func aFreeWeightGoalRingsTheCard() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        fixture.log(bench, reps: 5, weight: 100, on: .days(ago: 10))
        GoalScope.exercise(bench).set(reps: 5, weight: 120, at: .days(ago: 5))
        fixture.log(bench, reps: 5, weight: 110, on: .now)
        try fixture.save()

        let goal = try #require(try layout(fixture).resume?.goal)

        #expect(goal.isReached == false)
        #expect(goal.progress == 0.5)
    }

    @Test("An exercise with no goal leaves the card's ring empty")
    func noGoalNoRing() throws {
        let fixture = try LibraryFixture()
        fixture.log(fixture.exercise("Bench Press"), reps: 5, weight: 100, on: .now)
        try fixture.save()

        let resume = try #require(try layout(fixture).resume)

        #expect(resume.goal == nil)
    }

    @Test("A gym-bound card rings the goal of the machine the resumed entry was logged on")
    func aGymBoundCardRingsTheResumedMachine() throws {
        let fixture = try LibraryFixture()
        let press = fixture.exercise("Leg Press", kind: .gymBound)
        let home = fixture.machine(for: press, at: fixture.gym("Home"))
        let holiday = fixture.machine(for: press, at: fixture.gym("Holiday"))
        GoalScope.machine(home).set(reps: 8, weight: 200, at: .days(ago: 20))
        GoalScope.machine(holiday).set(reps: 8, weight: 120, at: .days(ago: 20))
        fixture.log(home, reps: 8, weight: 190, on: .days(ago: 3))
        fixture.log(holiday, reps: 8, weight: 60, on: .now)
        try fixture.save()

        let goal = try #require(try layout(fixture).resume?.goal)

        #expect(goal.weight == 120)
        #expect(goal.progress == 0.5)
    }

    @Test("A goal on a sibling machine never rings the card")
    func aSiblingMachinesGoalNeverRingsTheCard() throws {
        let fixture = try LibraryFixture()
        let press = fixture.exercise("Leg Press", kind: .gymBound)
        let home = fixture.machine(for: press, at: fixture.gym("Home"))
        let holiday = fixture.machine(for: press, at: fixture.gym("Holiday"))
        GoalScope.machine(home).set(reps: 8, weight: 200, at: .days(ago: 20))
        fixture.log(home, reps: 8, weight: 190, on: .days(ago: 3))
        fixture.log(holiday, reps: 8, weight: 60, on: .now)
        try fixture.save()

        let resume = try #require(try layout(fixture).resume)

        #expect(resume.goal == nil)
    }

    @Test("A reached goal stays on the card as a full ring, marked reached")
    func aReachedGoalIsAFullRing() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        GoalScope.exercise(bench).set(reps: 5, weight: 120, at: .days(ago: 5))
        fixture.log(bench, reps: 5, weight: 122.5, on: .now)
        try fixture.save()

        let goal = try #require(try layout(fixture).resume?.goal)

        #expect(goal.isReached)
        #expect(goal.progress == 1)
    }

    @Test("A goal leaves the tile's subtitle as it was")
    func tilesCarryNoGoal() throws {
        let fixture = try LibraryFixture()
        let bench = fixture.exercise("Bench Press")
        GoalScope.exercise(bench).set(reps: 5, weight: 120, at: .days(ago: 5))
        fixture.log(bench, reps: 5, weight: 100, on: .now)
        try fixture.save()

        let tile = try #require(try layout(fixture).tiles.first)

        // The subtitle is all a tile says: it has no goal to read at all, since a tile
        // would have to resolve a scope through the current gym.
        #expect(tile.lastEntry?.text(asOf: .now) == "5 × 100 kg · today")
    }

    // MARK: - Search

    @Test("Search matches anywhere in the name, ignoring case and diacritics")
    func searchIgnoresCaseAndDiacritics() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Bulgarian Split Squat")
        fixture.exercise("Bench Press")
        fixture.exercise("Curl")
        try fixture.save()
        let layout = try layout(fixture)

        #expect(layout.matches(query: "SQUAT").map(\.name) == ["Bulgarian Split Squat"])
        #expect(layout.matches(query: "prèss").map(\.name) == ["Bench Press"])
        #expect(layout.matches(query: "  ").count == 3)
    }

    @Test("A query nothing matches yields nothing")
    func aQueryNothingMatchesYieldsNothing() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Bench Press")
        try fixture.save()

        #expect(try layout(fixture).matches(query: "zzz").isEmpty)
    }
}
