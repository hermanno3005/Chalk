import Foundation
import Testing

@testable import Chalk

/// Which machine a gym-bound screen opens on, and what a gym-bound curve is derived
/// from (SPEC §5.3). The cascade has four rungs and the last one is *no machine at all*,
/// which is a screen state rather than an error.
@Suite("Machine scope")
struct MachineScopeTests {

    @Test("An exercise with no machines resolves none")
    func noMachinesResolvesNone() throws {
        let fixture = try LibraryFixture()
        let gym = fixture.gym("Fitness X")

        #expect(MachineScope.opening(machines: [], currentGym: gym) == nil)
    }

    @Test("The one machine at the current gym wins, logged or not")
    func theSingleMachineAtTheCurrentGymWins() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let current = fixture.gym("Fitness X")
        let elsewhere = fixture.gym("Old Barn")
        let here = fixture.machine(for: exercise, at: current, label: "By the window")
        let there = fixture.machine(for: exercise, at: elsewhere, label: "Blue one")
        fixture.log(there, reps: 5, weight: 100, on: .days(ago: 1))

        let opened = MachineScope.opening(machines: [there, here], currentGym: current)

        #expect(opened === here)
    }

    @Test("Several at the current gym: the one most recently logged on")
    func severalAtTheCurrentGymPickTheMostRecent() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let current = fixture.gym("Fitness X")
        let older = fixture.machine(for: exercise, at: current, label: "Plate loaded")
        let newer = fixture.machine(for: exercise, at: current, label: "Selectorised")
        fixture.log(older, reps: 5, weight: 100, on: .days(ago: 10))
        fixture.log(newer, reps: 5, weight: 80, on: .days(ago: 2))

        #expect(MachineScope.opening(machines: [older, newer], currentGym: current) === newer)
    }

    @Test("No machine at the current gym: the one most recently logged on anywhere")
    func fallsBackToTheMostRecentlyLoggedOverall() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let current = fixture.gym("Fitness X")
        let elsewhere = fixture.gym("Old Barn")
        let stale = fixture.machine(for: exercise, at: elsewhere, label: "Blue one")
        let recent = fixture.machine(for: exercise, at: elsewhere, label: "Red one")
        fixture.log(stale, reps: 5, weight: 100, on: .days(ago: 40))
        fixture.log(recent, reps: 5, weight: 90, on: .days(ago: 3))

        #expect(MachineScope.opening(machines: [stale, recent], currentGym: current) === recent)
    }

    @Test("No gym selected falls back the same way")
    func noCurrentGymFallsBackToRecency() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let elsewhere = fixture.gym("Old Barn")
        let stale = fixture.machine(for: exercise, at: elsewhere, label: "Blue one")
        let recent = fixture.machine(for: exercise, at: elsewhere, label: "Red one")
        fixture.log(stale, reps: 5, weight: 100, on: .days(ago: 40))
        fixture.log(recent, reps: 5, weight: 90, on: .days(ago: 3))

        #expect(MachineScope.opening(machines: [stale, recent], currentGym: nil) === recent)
    }

    @Test("Machines that exist but hold nothing still resolve one — by name")
    func unloggedMachinesStillResolve() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let elsewhere = fixture.gym("Old Barn")
        let zeta = fixture.machine(for: exercise, at: elsewhere, label: "Zeta")
        let alpha = fixture.machine(for: exercise, at: elsewhere, label: "Alpha")

        #expect(MachineScope.opening(machines: [zeta, alpha], currentGym: nil) === alpha)
    }

    // MARK: - What the curve is derived from

    @Test("A gym-bound curve counts only the scoped machine's entries")
    func gymBoundScopeIsOneMachine() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        let here = fixture.machine(for: exercise, at: gym, label: "By the window")
        let there = fixture.machine(for: exercise, at: gym, label: "Blue one")
        fixture.log(here, reps: 5, weight: 100)
        fixture.log(there, reps: 5, weight: 200)

        let scope = MachineScope.entries(of: exercise, on: here)

        #expect(scope.map(\.weight) == [100])
    }

    @Test("A free-weight curve counts every entry, machine or not")
    func freeWeightScopeIsTheWholeExercise() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Squat")
        fixture.log(exercise, reps: 5, weight: 100)
        fixture.log(exercise, reps: 3, weight: 120)

        #expect(MachineScope.entries(of: exercise, on: nil).count == 2)
    }

    @Test("A gym-bound exercise with no machine resolved derives from nothing")
    func gymBoundWithoutAMachineDerivesFromNothing() throws {
        let fixture = try LibraryFixture()
        let exercise = fixture.exercise("Leg Press", kind: .gymBound)
        // Only reachable before the first machine exists: a machine-less gym-bound
        // entry is not producible by any UI path (SPEC §3).
        fixture.log(exercise, reps: 5, weight: 100)

        #expect(MachineScope.entries(of: exercise, on: nil).isEmpty)
    }
}
