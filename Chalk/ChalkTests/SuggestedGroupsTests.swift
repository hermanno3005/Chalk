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
}
