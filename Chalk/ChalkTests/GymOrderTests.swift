import Foundation
import Testing

@testable import Chalk

/// Gym ordering (SPEC §7.4): **derived from entries — no stored index, no maintenance.**
/// `Gym` deliberately has no `sortIndex`, so an implementer reaching for one is going
/// the wrong way.
@Suite("Gym order")
struct GymOrderTests {

    @Test("Gyms order by when you last logged an entry there")
    func gymsOrderByRecency() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let stale = fixture.gym("Holiday Gym")
        let recent = fixture.gym("Fitness X")
        let middling = fixture.gym("Old Barn")
        fixture.log(fixture.machine(for: exercise, at: stale), reps: 5, weight: 60, on: .days(ago: 90))
        fixture.log(fixture.machine(for: exercise, at: recent), reps: 5, weight: 60, on: .days(ago: 1))
        fixture.log(fixture.machine(for: exercise, at: middling), reps: 5, weight: 60, on: .days(ago: 20))

        let ordered = GymOrder.byRecency([stale, recent, middling])

        #expect(ordered.map(\.name) == ["Fitness X", "Old Barn", "Holiday Gym"])
    }

    @Test("A gym you have never logged at sinks below the ones you have")
    func neverLoggedGymsSinkToTheBottom() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let fresh = fixture.gym("Just Created")
        let used = fixture.gym("Fitness X")
        fixture.log(fixture.machine(for: exercise, at: used), reps: 5, weight: 60, on: .days(ago: 400))

        #expect(GymOrder.byRecency([fresh, used]).map(\.name) == ["Fitness X", "Just Created"])
    }

    @Test("Gyms nobody has logged at order by name")
    func unloggedGymsOrderByName() throws {
        let fixture = try LibraryFixture()
        let zeta = fixture.gym("Zeta")
        let alpha = fixture.gym("Alpha")

        #expect(GymOrder.byRecency([zeta, alpha]).map(\.name) == ["Alpha", "Zeta"])
    }

    @Test("The current gym is pinned to the top however long ago you logged there")
    func theCurrentGymIsPinned() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let current = fixture.gym("Holiday Gym")
        let recent = fixture.gym("Fitness X")
        fixture.log(fixture.machine(for: exercise, at: current), reps: 5, weight: 60, on: .days(ago: 90))
        fixture.log(fixture.machine(for: exercise, at: recent), reps: 5, weight: 60, on: .days(ago: 1))

        let ordered = GymOrder.byRecency([current, recent], current: current)

        #expect(ordered.map(\.name) == ["Holiday Gym", "Fitness X"])
    }

    @Test("A zeroed row is not something you did, so it does not float a gym")
    func recencyCountsLiftsOnly() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let zeroed = fixture.gym("Ghost Gym")
        let real = fixture.gym("Fitness X")
        fixture.log(fixture.machine(for: exercise, at: zeroed), reps: 0, weight: 0, on: .days(ago: 1))
        fixture.log(fixture.machine(for: exercise, at: real), reps: 5, weight: 60, on: .days(ago: 30))

        #expect(GymOrder.byRecency([zeroed, real]).map(\.name) == ["Fitness X", "Ghost Gym"])
    }
}
