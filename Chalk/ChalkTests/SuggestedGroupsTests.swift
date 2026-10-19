import Foundation
import SwiftData
import Testing

@testable import Chalk

/// `Compound / Legs / Push / Pull / Core` ships as a **suggestion**, seeded on first
/// launch and thereafter ordinary renameable, deletable data — never a hard-coded list
/// the screen falls back to (SPEC §7.2).
@Suite("Suggested groups")
struct SuggestedGroupsTests {

    @Test("First launch seeds the five suggestions in their listed order")
    func firstLaunchSeedsTheFive() throws {
        let fixture = try LibraryFixture()

        SuggestedGroups.seedIfNeeded(in: fixture.context, defaults: fixture.defaults)

        let seeded = try fixture.allGroups().sorted { $0.sortIndex < $1.sortIndex }
        #expect(seeded.map(\.name) == ["Compound", "Legs", "Push", "Pull", "Core"])
        #expect(seeded.map(\.sortIndex) == [0, 1, 2, 3, 4])
    }

    @Test("Seeded groups are data: renaming one sticks, and a relaunch does not restore it")
    func seededGroupsAreOrdinaryData() throws {
        let fixture = try LibraryFixture()
        SuggestedGroups.seedIfNeeded(in: fixture.context, defaults: fixture.defaults)

        let legs = try #require(try fixture.allGroups().first { $0.name == "Legs" })
        legs.name = "Lower body"
        try fixture.save()
        SuggestedGroups.seedIfNeeded(in: fixture.context, defaults: fixture.defaults)

        let names = try fixture.afterRelaunch().fetch(FetchDescriptor<ExerciseGroup>()).map(\.name)
        #expect(names.sorted() == ["Compound", "Core", "Lower body", "Pull", "Push"])
    }

    @Test("A second launch seeds nothing, even with every suggestion deleted")
    func aSecondLaunchSeedsNothing() throws {
        let fixture = try LibraryFixture()
        SuggestedGroups.seedIfNeeded(in: fixture.context, defaults: fixture.defaults)
        for group in try fixture.allGroups() {
            fixture.context.delete(group)
        }
        try fixture.save()

        SuggestedGroups.seedIfNeeded(in: fixture.context, defaults: fixture.defaults)

        #expect(try fixture.allGroups().isEmpty)
    }

    @Test("A store that already holds groups is never seeded into")
    func aStoreWithGroupsIsNeverSeededInto() throws {
        let fixture = try LibraryFixture()
        fixture.group("Legs", sortIndex: 0)
        try fixture.save()

        SuggestedGroups.seedIfNeeded(in: fixture.context, defaults: fixture.defaults)

        #expect(try fixture.allGroups().map(\.name) == ["Legs"])
    }

    // MARK: - Endurance

    @Test("First launch seeds the three endurance suggestions in their listed order")
    func firstLaunchSeedsTheThreeEnduranceGroups() throws {
        let fixture = try LibraryFixture()

        SuggestedGroups.seedIfNeeded(.endurance, in: fixture.context, defaults: fixture.defaults)

        let seeded = try fixture.allGroups().sorted { $0.sortIndex < $1.sortIndex }
        #expect(seeded.map(\.name) == ["Treadmills", "Rowing & Ski", "Bikes"])
        #expect(seeded.map(\.sortIndex) == [0, 1, 2])
        #expect(seeded.allSatisfy { $0.half == Half.endurance.rawValue })
    }

    @Test("A store that already holds strength groups still gets the endurance groups, once")
    func anExistingInstallGetsTheEnduranceGroupsOnce() throws {
        let fixture = try LibraryFixture()
        // An install from before endurance: its strength seed ran long ago.
        SuggestedGroups.seedIfNeeded(in: fixture.context, defaults: fixture.defaults)
        fixture.group("Grip", sortIndex: 5)
        try fixture.save()

        SuggestedGroups.seedIfNeeded(.endurance, in: fixture.context, defaults: fixture.defaults)
        SuggestedGroups.seedIfNeeded(.endurance, in: fixture.context, defaults: fixture.defaults)

        #expect(try fixture.allGroups(.endurance).map(\.name) == ["Treadmills", "Rowing & Ski", "Bikes"])
        #expect(try fixture.allGroups(.strength).map(\.name) == ["Compound", "Legs", "Push", "Pull", "Core", "Grip"])
    }

    @Test("A deleted endurance suggestion stays deleted")
    func aDeletedEnduranceSuggestionStaysDeleted() throws {
        let fixture = try LibraryFixture()
        SuggestedGroups.seedIfNeeded(.endurance, in: fixture.context, defaults: fixture.defaults)
        let bikes = try #require(try fixture.allGroups(.endurance).first { $0.name == "Bikes" })
        fixture.context.delete(bikes)
        try fixture.save()

        SuggestedGroups.seedIfNeeded(.endurance, in: fixture.context, defaults: fixture.defaults)

        #expect(try fixture.allGroups(.endurance).map(\.name) == ["Treadmills", "Rowing & Ski"])
    }

    @Test("Each half's seed counts only its own groups")
    func eachHalfsSeedCountsOnlyItsOwnGroups() throws {
        let fixture = try LibraryFixture()

        // Endurance first: strength's guard must not read these as its own seed.
        SuggestedGroups.seedIfNeeded(.endurance, in: fixture.context, defaults: fixture.defaults)
        SuggestedGroups.seedIfNeeded(.strength, in: fixture.context, defaults: fixture.defaults)

        #expect(try fixture.allGroups(.strength).map(\.name) == ["Compound", "Legs", "Push", "Pull", "Core"])
        #expect(try fixture.allGroups(.endurance).map(\.name) == ["Treadmills", "Rowing & Ski", "Bikes"])
    }

    @Test("A store that already holds endurance groups is never seeded into")
    func aStoreWithEnduranceGroupsIsNeverSeededInto() throws {
        let fixture = try LibraryFixture()
        fixture.group("Rowers", sortIndex: 0, half: .endurance)
        try fixture.save()

        SuggestedGroups.seedIfNeeded(.endurance, in: fixture.context, defaults: fixture.defaults)

        #expect(try fixture.allGroups(.endurance).map(\.name) == ["Rowers"])
    }
}
