import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The home screen in two halves (SPEC §13.5): **one `LibraryModel` scoped to the half
/// on screen**, so its grid, search, groups and the create path all read that half and
/// nothing of the other's.
///
/// The rules an implementer gets subtly wrong: **search never covers both halves** — a
/// query typed on one never surfaces the other's tiles, and *Create it* follows the half
/// it was typed on — and **the half is per device and sticky**, so a second model over
/// the same defaults opens where the first one left off, and a fresh suite opens on
/// strength.
@Suite("Library halves")
struct LibraryHalvesTests {

    // MARK: - The switch

    @Test("First launch opens on Strength")
    func firstLaunchOpensOnStrength() throws {
        let fixture = try LibraryFixture()

        #expect(fixture.libraryModel().half == .strength)
    }

    @Test("The app reopens on the half you left it in")
    func theAppReopensOnTheLastHalf() throws {
        let fixture = try LibraryFixture()
        fixture.libraryModel().show(.endurance)

        #expect(fixture.libraryModel().half == .endurance)

        fixture.libraryModel().show(.strength)

        #expect(fixture.libraryModel().half == .strength)
    }

    @Test("Switching lands on the other half's home screen, not on a search")
    func switchingLandsOnTheHomeScreen() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Squat")
        fixture.erg("Treadmill")
        try fixture.save()
        let model = fixture.libraryModel()
        model.search("sq")

        model.show(.endurance)

        #expect(model.query.isEmpty)
        #expect(model.content.drawn == "grid Ungrouped[Treadmill]")
    }

    // MARK: - The grid

    @Test("Each half's grid holds only its own: lifts on strength, ergs on endurance")
    func eachHalfsGridHoldsOnlyItsOwn() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Squat")
        fixture.erg("Treadmill")
        fixture.erg("RowErg", unit: .split, kind: .freeWeight)
        try fixture.save()
        let model = fixture.libraryModel()

        #expect(model.content.drawn == "grid Ungrouped[Squat]")

        model.show(.endurance)

        #expect(model.content.drawn == "grid Ungrouped[RowErg, Treadmill]")
    }

    @Test("With no ergs, endurance is the empty state, its seeded groups hidden")
    func noErgsIsTheEmptyState() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Squat")
        try fixture.save()
        let model = fixture.libraryModel()

        model.show(.endurance)

        #expect(model.groups.groups.map(\.name) == ["Treadmills", "Rowing & Ski", "Bikes"])
        #expect(model.content.drawn == "empty")
    }

    @Test("An erg sits in its endurance group's section")
    func anErgSitsInItsGroupsSection() throws {
        let fixture = try LibraryFixture()
        let rowing = fixture.enduranceGroup("Rowing & Ski", sortIndex: 0)
        fixture.erg("SkiErg", unit: .split, group: rowing)
        fixture.erg("Stairmaster", unit: .level)
        try fixture.save()
        let model = fixture.libraryModel()

        model.show(.endurance)

        #expect(model.content.drawn == "grid Rowing & Ski[SkiErg] Ungrouped[Stairmaster]")
    }

    // MARK: - Search

    @Test("Search never covers both halves")
    func searchNeverCoversBothHalves() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Bike Crunch")
        fixture.erg("Bike Erg", unit: .watts)
        try fixture.save()
        let model = fixture.libraryModel()

        model.search("bike")
        #expect(model.content.drawn == "searching [Bike Crunch]")

        model.show(.endurance)
        model.search("bike")
        #expect(model.content.drawn == "searching [Bike Erg]")
    }

    @Test("A name only the other half holds offers Create it on this one")
    func theOtherHalfsNameOffersCreateIt() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Squat")
        try fixture.save()
        let model = fixture.libraryModel()
        model.show(.endurance)

        model.search("Squat")

        #expect(model.content.drawn == "searching [] create \"Squat\"")
    }

    // MARK: - Groups, Arrange and Edit groups

    @Test("Each half's groups are its own, in its own order")
    func eachHalfsGroupsAreItsOwn() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()

        #expect(model.groups.groups.map(\.name) == ["Compound", "Legs", "Push", "Pull", "Core"])

        model.show(.endurance)

        #expect(model.groups.groups.map(\.name) == ["Treadmills", "Rowing & Ski", "Bikes"])
    }

    @Test("A group added in endurance is an endurance group, and strength never sees it")
    func aGroupAddedInEnduranceIsEndurances() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.show(.endurance)

        let stairs = try #require(model.groups.create(named: "Stairs"))

        #expect(stairs.half == Half.endurance.rawValue)
        #expect(stairs.sortIndex == 3)
        model.show(.strength)
        #expect(!model.groups.groups.contains { $0 === stairs })
    }

    @Test("Reordering endurance groups leaves strength's order alone")
    func reorderingOneHalfLeavesTheOther() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.show(.endurance)

        model.groups.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(model.groups.groups.map(\.name) == ["Bikes", "Treadmills", "Rowing & Ski"])
        #expect(try fixture.allGroups(.strength).map(\.sortIndex) == [0, 1, 2, 3, 4])
        #expect(try fixture.allGroups(.strength).map(\.name) == ["Compound", "Legs", "Push", "Pull", "Core"])
    }

    @Test("Arrange files an erg into an endurance group")
    func arrangeFilesAnErg() throws {
        let fixture = try LibraryFixture()
        fixture.erg("Treadmill")
        try fixture.save()
        let model = fixture.libraryModel()
        model.show(.endurance)
        let erg = try #require(try fixture.allExercises().first)
        let treadmills = try #require(model.groups.groups.first { $0.name == "Treadmills" })

        model.assign(erg, to: treadmills)

        #expect(model.content.drawn == "grid Treadmills[Treadmill]")
    }

    @Test("An erg is never filed into a strength group, nor a lift into an endurance one")
    func nothingIsFiledAcrossHalves() throws {
        let fixture = try LibraryFixture()
        let push = fixture.group("Push", sortIndex: 0)
        let bikes = fixture.enduranceGroup("Bikes", sortIndex: 0)
        let erg = fixture.erg("Bike Erg", unit: .watts)
        let lift = fixture.exercise("Bench Press")
        try fixture.save()
        let model = fixture.libraryModel()

        model.assign(erg, to: push)
        model.assign(lift, to: bikes)
        #expect(model.assign(exerciseWithID: erg.id, to: push) == false)

        #expect(erg.group == nil)
        #expect(lift.group == nil)
    }
}
