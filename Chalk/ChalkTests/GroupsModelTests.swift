import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The four verbs Edit groups offers — reorder, rename, delete, add (SPEC §7.2).
///
/// Groups are **user-owned ordered buckets, not a taxonomy**, and a user-owned thing you
/// cannot rename, reorder or delete is not actually user-owned. The order these hold is
/// the order the library's sections draw in, which is the whole reason reordering is the
/// sheet's primary action rather than an afterthought.
@Suite("Groups model")
struct GroupsModelTests {

    // MARK: - Order

    @Test("Groups come out in the user's own order, ties by name")
    func groupsComeOutInSortIndexOrder() throws {
        let fixture = try LibraryFixture()
        fixture.group("Push", sortIndex: 2)
        fixture.group("Compound", sortIndex: 0)
        fixture.group("Legs", sortIndex: 1)
        try fixture.save()

        #expect(fixture.groupsModel().groups.map(\.name) == ["Compound", "Legs", "Push"])
    }

    // MARK: - Add

    @Test("A created group lands last and survives relaunch")
    func aCreatedGroupLandsLast() throws {
        let fixture = try LibraryFixture()
        fixture.group("Compound", sortIndex: 0)
        try fixture.save()
        let model = fixture.groupsModel()

        let created = try #require(model.create(named: "Grip"))

        #expect(created.sortIndex == 1)
        #expect(model.groups.map(\.name) == ["Compound", "Grip"])
        let relaunched = try fixture.afterRelaunch().fetch(FetchDescriptor<ExerciseGroup>())
        #expect(relaunched.map(\.name).sorted() == ["Compound", "Grip"])
    }

    @Test("A group added to an empty store starts the order at zero")
    func theFirstGroupStartsAtZero() throws {
        let fixture = try LibraryFixture()

        #expect(fixture.groupsModel().create(named: "Grip")?.sortIndex == 0)
    }

    @Test("A name that is blank once trimmed creates nothing")
    func aBlankNameCreatesNothing() throws {
        let fixture = try LibraryFixture()
        let model = fixture.groupsModel()

        #expect(model.create(named: "   ") == nil)
        #expect(model.groups.isEmpty)
    }

    @Test("Two groups may share a name — this is a shelf, not a taxonomy")
    func duplicateNamesAreAllowed() throws {
        let fixture = try LibraryFixture()
        let model = fixture.groupsModel()

        model.create(named: "Legs")
        model.create(named: "Legs")

        #expect(model.groups.map(\.name) == ["Legs", "Legs"])
    }

    // MARK: - Rename

    @Test("Renaming keeps the group's place and every exercise on it")
    func renamingKeepsPlaceAndExercises() throws {
        let fixture = try LibraryFixture()
        let compound = fixture.group("Compound", sortIndex: 0)
        fixture.group("Legs", sortIndex: 1)
        fixture.exercise("Squat", group: compound)
        try fixture.save()
        let model = fixture.groupsModel()

        model.rename(compound, to: "  Big lifts  ")

        #expect(model.groups.map(\.name) == ["Big lifts", "Legs"])
        #expect(compound.exercises?.map(\.name) == ["Squat"])
        let relaunched = try fixture.afterRelaunch().fetch(FetchDescriptor<ExerciseGroup>())
        #expect(relaunched.contains { $0.name == "Big lifts" })
    }

    @Test("Renaming to blank leaves the name alone")
    func renamingToBlankIsANoOp() throws {
        let fixture = try LibraryFixture()
        let compound = fixture.group("Compound", sortIndex: 0)
        try fixture.save()
        let model = fixture.groupsModel()

        model.rename(compound, to: " ")

        #expect(model.groups.map(\.name) == ["Compound"])
    }

    // MARK: - Delete

    @Test("Deleting a group moves its exercises to Ungrouped and deletes nothing else")
    func deletingAGroupKeepsItsExercises() throws {
        let fixture = try LibraryFixture()
        let compound = fixture.group("Compound", sortIndex: 0)
        let legs = fixture.group("Legs", sortIndex: 1)
        let squat = fixture.exercise("Squat", group: compound)
        fixture.exercise("Leg Curl", group: legs)
        fixture.log(squat, reps: 5, weight: 100)
        try fixture.save()
        let model = fixture.groupsModel()

        model.delete(compound)

        #expect(model.groups.map(\.name) == ["Legs"])
        #expect(squat.group == nil)
        // The exercise and its entries are untouched: deleting a shelf is not deleting
        // what was on it (SPEC §7.2, §3's nullify rule).
        let relaunched = try fixture.afterRelaunch()
        #expect(try relaunched.fetchCount(FetchDescriptor<Exercise>()) == 2)
        #expect(try relaunched.fetchCount(FetchDescriptor<Entry>()) == 1)
        #expect(try relaunched.fetchCount(FetchDescriptor<ExerciseGroup>()) == 1)
    }

    // MARK: - Reorder

    @Test("Reordering renumbers densely and survives relaunch")
    func reorderingRenumbersDensely() throws {
        let fixture = try LibraryFixture()
        fixture.group("Compound", sortIndex: 0)
        fixture.group("Legs", sortIndex: 1)
        fixture.group("Push", sortIndex: 2)
        try fixture.save()
        let model = fixture.groupsModel()

        // Push to the front — the dev's original ask, in the other direction.
        model.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(model.groups.map(\.name) == ["Push", "Compound", "Legs"])
        #expect(model.groups.map(\.sortIndex) == [0, 1, 2])
        let relaunched = try fixture.afterRelaunch()
            .fetch(FetchDescriptor<ExerciseGroup>())
            .sorted { $0.sortIndex < $1.sortIndex }
        #expect(relaunched.map(\.name) == ["Push", "Compound", "Legs"])
    }

    @Test("A move that lands where it started changes nothing")
    func aMoveToTheSamePlaceChangesNothing() throws {
        let fixture = try LibraryFixture()
        fixture.group("Compound", sortIndex: 0)
        fixture.group("Legs", sortIndex: 1)
        try fixture.save()
        let model = fixture.groupsModel()

        model.move(fromOffsets: IndexSet(integer: 0), toOffset: 0)

        #expect(model.groups.map(\.name) == ["Compound", "Legs"])
    }
}
