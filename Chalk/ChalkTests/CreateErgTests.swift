import Foundation
import SwiftData
import Testing

@testable import Chalk

/// Creating an erg (SPEC §13.6): **Save waits for a unit** — Chalk never guesses one,
/// because a unit has no repair once the erg has entries — and the sheet **starts on
/// gym-bound**, the cheaper mistake. Gym-bound reveals no machine fields: the first log
/// resolves the machine, so none is made here, whatever the current gym.
@Suite("Creating an erg")
struct CreateErgTests {

    @Test("A new erg starts on no unit and gym-bound, in Ungrouped")
    func aNewErgStartsOnNoUnitAndGymBound() {
        let draft = NewErg(name: "Treadmill")

        #expect(draft.unit == nil)
        #expect(draft.kind == .gymBound)
        #expect(draft.groupID == nil)
    }

    @Test("Save stays disabled until a unit is chosen")
    func saveWaitsForAUnit() {
        var draft = NewErg(name: "Treadmill")
        #expect(!draft.canSave)

        draft.unit = .speed

        #expect(draft.canSave)
    }

    @Test("Save stays disabled for a name that is blank once trimmed")
    func saveWaitsForAName() {
        var draft = NewErg(name: "   ")
        draft.unit = .watts

        #expect(!draft.canSave)
    }

    @Test("Without a unit, no erg is created")
    func noUnitCreatesNothing() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.show(.endurance)

        #expect(model.create(NewErg(name: "Treadmill")) == nil)
        #expect(try fixture.allExercises().isEmpty)
        #expect(model.content.drawn == "empty")
    }

    @Test("A created erg keeps its unit and kind, lands on endurance's grid and survives relaunch")
    func aCreatedErgLandsOnTheGrid() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.show(.endurance)
        var draft = NewErg(name: " RowErg ")
        draft.unit = .split
        draft.kind = .freeWeight

        let erg = try #require(model.create(draft))

        #expect(erg.name == "RowErg")
        #expect(erg.ergUnit == .split)
        #expect(!erg.isGymBound)
        #expect(model.content.drawn == "grid Ungrouped[RowErg]")
        let relaunched = try fixture.afterRelaunch().fetch(FetchDescriptor<Exercise>())
        #expect(relaunched.map(\.unit) == ["split"])
        model.show(.strength)
        #expect(model.content.drawn == "empty")
    }

    @Test("A gym-bound erg is created with no machine: the first log makes one")
    func aGymBoundErgHasNoMachine() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.gyms.select(try #require(model.gyms.create(named: "Fitness X")))
        model.show(.endurance)
        var draft = NewErg(name: "Treadmill")
        draft.unit = .speed

        let erg = try #require(model.create(draft))

        #expect(erg.isGymBound)
        #expect(erg.machines?.isEmpty == true)
    }

    @Test("An erg created into an endurance group lands in its section")
    func anErgCreatedIntoAGroupLandsInItsSection() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.show(.endurance)
        let bikes = try #require(model.groups.groups.first { $0.name == "Bikes" })
        var draft = NewErg(name: "Bike Erg")
        draft.unit = .watts
        draft.groupID = bikes.id

        let erg = try #require(model.create(draft))

        #expect(erg.group === bikes)
        #expect(model.content.drawn == "grid Bikes[Bike Erg]")
    }

    @Test("An erg is never created into a strength group")
    func anErgIsNeverCreatedIntoAStrengthGroup() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        let push = try #require(model.groups.groups.first { $0.name == "Push" })
        model.show(.endurance)
        var draft = NewErg(name: "Bike Erg")
        draft.unit = .watts
        draft.groupID = push.id

        let erg = try #require(model.create(draft))

        #expect(erg.group == nil)
    }

    @Test("Create it makes an erg of the typed name and returns to the grid")
    func createItMakesAnErg() throws {
        let fixture = try LibraryFixture()
        let model = fixture.libraryModel()
        model.show(.endurance)
        model.search("SkiErg")
        var draft = NewErg(name: "SkiErg")
        draft.unit = .split

        try #require(model.create(draft))

        #expect(model.query.isEmpty)
        #expect(model.content.drawn == "grid Ungrouped[SkiErg]")
    }
}
