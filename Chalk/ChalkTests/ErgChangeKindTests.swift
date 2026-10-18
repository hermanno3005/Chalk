import Foundation
import SwiftData
import Testing

@testable import Chalk

/// `Change kind` on an erg — transferable ↔ gym-bound (SPEC §8, §13.11, #118).
///
/// The mechanism is strength's unchanged, and so is the line every test here is measured
/// against: **no interval is lost**. Deleting a `Machine` cascades to its entries (SPEC
/// §3), so pooling detaches every entry and flushes before a single machine row goes
/// (ADR-0002). What changes is the wording — **the endurance wording never says
/// *curve*** — and only the scope moves: unit and incline are untouched.
@Suite("Change kind on an erg")
struct ErgChangeKindTests {

    // MARK: - The words

    @Test("Pooling an erg says its entries will be read as one, with the machine count")
    func poolingNamesTheMachineCount() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let gym = fixture.gym("FitX")
        for label in ["Technogym Excite", "Life Fitness", "Matrix"] {
            fixture.interval(treadmill, machine: fixture.machine(for: treadmill, at: gym, label: label))
        }

        let change = KindChange(exercise: treadmill)

        #expect(change.direction == .toFreeWeight)
        #expect(change.question == "Treadmill has entries on 3 machines. They'll be read as one.")
        #expect(change.detail == "Every entry is kept. 3 machines are deleted, and this cannot be undone.")
        #expect(change.confirmButton == "Make transferable")
    }

    @Test("Making a transferable erg gym-bound asks which machine it is on, and counts what moves")
    func theFlipToGymBoundAsksWhichMachine() throws {
        let fixture = try LibraryFixture()
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        fixture.interval(rower, intensity: 120, on: .days(ago: 2))
        fixture.interval(rower, intensity: 118, on: .days(ago: 1))

        let change = KindChange(exercise: rower)

        #expect(change.direction == .toGymBound)
        #expect(change.needsAMachine)
        #expect(change.prompt == "Which machine is this on?")
        #expect(change.promptDetail == "Rower becomes gym-bound, and all 2 entries move to the machine you pick.")
    }

    @Test("One machine is not read as one with anything, and says so")
    func poolingFromASingleMachine() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let gym = fixture.gym("FitX")
        fixture.interval(treadmill, machine: fixture.machine(for: treadmill, at: gym, label: "Technogym Excite"))
        fixture.machine(for: treadmill, at: gym, label: "Never used")

        let change = KindChange(exercise: treadmill)

        #expect(change.question == "Treadmill has entries on one machine. They'll be read as the erg's own.")
        #expect(change.detail == "Every entry is kept. 2 machines are deleted, and this cannot be undone.")
    }

    @Test("Nothing logged asks plainly, both ways, and a gym-bound erg is told to log a block")
    func nothingLoggedAsksPlainly() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("Bike", unit: .watts, kind: .freeWeight)
        let treadmill = fixture.erg("Treadmill")
        fixture.machine(for: treadmill, at: fixture.gym("FitX"))

        let toGymBound = KindChange(exercise: bike)
        let toTransferable = KindChange(exercise: treadmill)

        #expect(!toGymBound.needsAMachine)
        #expect(toGymBound.question == "Make Bike gym-bound?")
        #expect(toGymBound.detail == "Its numbers will be kept per machine. Log a block and name the machine you are on.")
        #expect(toGymBound.confirmButton == "Make gym-bound")
        #expect(toTransferable.question == "Make Treadmill transferable?")
        #expect(toTransferable.detail == "Nothing is logged on 1 machine. It is deleted, and this cannot be undone.")
    }

    @Test("The endurance wording never says curve", arguments: [0, 1, 3])
    func neverSaysCurve(machinesLogged: Int) throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        let gym = fixture.gym("FitX")
        for index in 0..<3 {
            let machine = fixture.machine(for: treadmill, at: gym, label: "Machine \(index)")
            if index < machinesLogged {
                fixture.interval(treadmill, machine: machine)
                fixture.interval(rower)
            }
        }

        for change in [KindChange(exercise: treadmill), KindChange(exercise: rower)] {
            let words = [change.question, change.detail, change.confirmButton, change.prompt, change.promptDetail]
            #expect(words.allSatisfy { !$0.localizedCaseInsensitiveContains("curve") }, "\(words)")
            #expect(words.allSatisfy { !$0.localizedCaseInsensitiveContains("free-weight") }, "\(words)")
        }
    }

    // MARK: - Transferable → gym-bound

    @Test("Every interval moves to the machine you pick, keeping its unit and incline")
    func everyIntervalMovesToTheMachine() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, intensity: 12.0, incline: 1, on: .days(ago: 3))
        fixture.interval(treadmill, intensity: 15.5, incline: 0, on: .days(ago: 2))
        fixture.interval(treadmill, intensity: 9.0, incline: 6.5, on: .days(ago: 1))
        let gym = fixture.gym("FitX")
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        model.makeGymBound(at: gym, named: "Technogym Excite")

        let machine = try #require(treadmill.machines?.first)
        #expect(treadmill.isGymBound)
        #expect(treadmill.machines?.count == 1)
        #expect(machine.name == "Technogym Excite")
        #expect(machine.gym === gym)
        #expect(treadmill.entries?.allSatisfy { $0.machine === machine } == true)

        // The screen takes the shape: the qualifier appears, on the only machine there is.
        #expect(model.isGymBound)
        #expect(model.machine === machine)
        #expect(model.entryCount == 3)

        let reopened = try fixture.afterRelaunch()
        let entries = try reopened.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date)]))
        #expect(entries.count == 3)
        #expect(entries.allSatisfy { $0.machine?.name == "Technogym Excite" })
        #expect(entries.map(\.intensity) == [12.0, 15.5, 9.0])
        #expect(entries.map(\.incline) == [1, 0, 6.5])
        #expect(try reopened.fetch(FetchDescriptor<Exercise>()).first?.ergUnit == .speed)
    }

    @Test("Nothing logged makes no machine — the empty state until the first block makes one")
    func nothingLoggedLeavesNoMachine() throws {
        let fixture = try LibraryFixture()
        let bike = fixture.erg("Bike", unit: .watts, kind: .freeWeight)
        try fixture.save()
        let model = fixture.ergDetailModel(for: bike)

        model.makeGymBound()

        #expect(bike.isGymBound)
        #expect(bike.machines?.isEmpty == true)
        #expect(model.isGymBound)
        #expect(model.machine == nil)
        #expect(bike.ergUnit == .watts)
    }

    @Test("Each direction is refused from the kind the erg already is")
    func eachDirectionIsRefusedFromItsOwnKind() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let machine = fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Technogym Excite")
        fixture.interval(treadmill, machine: machine)
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        fixture.interval(rower, intensity: 120)
        try fixture.save()

        fixture.ergDetailModel(for: treadmill).makeGymBound(at: fixture.gym("Old Barn"), named: "Nope")
        fixture.ergDetailModel(for: rower).makeTransferable()
        // With an interval to place, the flip that asks nothing is refused too.
        fixture.ergDetailModel(for: rower).makeGymBound()

        #expect(treadmill.machines?.count == 1)
        #expect(machine.entries?.count == 1)
        #expect(!rower.isGymBound)
        #expect(rower.machines?.isEmpty == true)
        #expect(rower.entries?.count == 1)
    }

    // MARK: - Gym-bound → transferable

    @Test("Pooling keeps every interval, with its unit and incline, and deletes the machines")
    func poolingKeepsEveryInterval() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let fitX = fixture.gym("FitX")
        let barn = fixture.gym("Old Barn")
        let excite = fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")
        let matrix = fixture.machine(for: treadmill, at: fitX, label: "Matrix")
        let lifeFitness = fixture.machine(for: treadmill, at: barn, label: "Life Fitness")
        fixture.interval(treadmill, machine: excite, intensity: 12.0, incline: 1, on: .days(ago: 4))
        fixture.interval(treadmill, machine: excite, intensity: 15.5, incline: 0, on: .days(ago: 3))
        fixture.interval(treadmill, machine: matrix, intensity: 9.0, incline: 6.5, on: .days(ago: 2))
        fixture.interval(treadmill, machine: lifeFitness, intensity: 14.0, incline: 2, on: .days(ago: 1))
        try fixture.save()
        let model = fixture.ergDetailModel(for: treadmill)

        model.makeTransferable()

        #expect(!treadmill.isGymBound)
        #expect(treadmill.machines?.isEmpty == true)
        #expect(treadmill.entries?.allSatisfy { $0.machine == nil } == true)

        // The qualifier goes, and the count still holds every interval.
        #expect(!model.isGymBound)
        #expect(model.machine == nil)
        #expect(model.machines.isEmpty)
        #expect(model.entryCount == 4)

        // What reached the disk: four intervals and no machines — the cascade from
        // `Machine` to its entries is the hazard this direction is written around.
        let reopened = try fixture.afterRelaunch()
        let entries = try reopened.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.date)]))
        #expect(entries.count == 4)
        #expect(entries.allSatisfy { $0.machine == nil && $0.exercise?.name == "Treadmill" })
        #expect(entries.map(\.intensity) == [12.0, 15.5, 9.0, 14.0])
        #expect(entries.map(\.incline) == [1, 0, 6.5, 2])
        #expect(try reopened.fetchCount(FetchDescriptor<Machine>()) == 0)
        #expect(try reopened.fetchCount(FetchDescriptor<Gym>()) == 2)
        #expect(try reopened.fetch(FetchDescriptor<Exercise>()).first?.ergUnit == .speed)
    }
}
