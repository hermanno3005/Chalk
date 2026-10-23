import Foundation
import SwiftData
import Testing

@testable import Chalk

/// Changing a unit on Settings (SPEC §15.2, ADR-0009). With nothing yet written on a scale,
/// a change is just a change. Once there is, it is a **relabel**: every stored number stays
/// as it is and only the scale changes, confirmed in words that say so, never a silent
/// switch.
@Suite("Relabel")
struct RelabelTests {

    @Test("A library on kg relabelled to lb keeps every stored number and reads lb")
    func relabellingWeightsKeepsEveryNumber() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.kg)
        let squat = fixture.exercise("Squat")
        fixture.log(squat, reps: 5, weight: 100)
        GoalScope.exercise(squat).set(reps: 5, weight: 120)
        try fixture.save()
        let library = fixture.libraryModel()
        let settings = library.settings()

        settings.change(weightsTo: .lb)

        #expect(settings.unitChange != nil)
        #expect(WeightUnit.stored(in: fixture.defaults) == .kg)

        settings.relabel()
        // What closing Settings does to the library behind it.
        library.refresh()

        #expect(settings.unitChange == nil)
        #expect(settings.weightUnit == .lb)
        #expect(WeightUnit.stored(in: fixture.defaults) == .lb)
        let store = try fixture.afterRelaunch()
        #expect(try store.fetch(FetchDescriptor<Entry>()).map(\.weight) == [100])
        #expect(try store.fetch(FetchDescriptor<Exercise>()).map(\.goalWeight) == [120])
        #expect(library.resume?.text() == "5 × 100 lb · today")
        guard case .grid(let sections) = library.content else {
            Issue.record("Expected the grid")
            return
        }
        #expect(sections[0].tiles[0].subtitle() == "5 × 100 lb · today")
    }

    @Test("A library on km relabelled to miles keeps every stored speed and reads mph")
    func relabellingDistancesKeepsEveryNumber() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        fixture.distanceUnit(.km)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 9.3, incline: 1, average: 164, peak: 170)
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 9.7, incline: 1)
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(distancesTo: .mi)

        #expect(settings.unitChange != nil)
        #expect(DistanceUnit.stored(in: fixture.defaults) == .km)

        settings.relabel()

        #expect(settings.distanceUnit == .mi)
        #expect(DistanceUnit.stored(in: fixture.defaults) == .mi)
        let store = try fixture.afterRelaunch()
        #expect(try store.fetch(FetchDescriptor<Entry>()).map(\.intensity) == [9.3])
        #expect(try store.fetch(FetchDescriptor<Exercise>()).map(\.goalIntensity) == [9.7])
        let readout = fixture.ergDetailModel(for: treadmill).readout
        #expect(readout?.intensity.decimalPoint == "9.3 mph")
        #expect(readout?.pace == "6:27 /mi")
    }

    @Test("The question says, in words, that a relabel moves no number", arguments: [
        (UnitChange.weights(.lb), "Write weights in lb?", "Relabel as lb",
         "Relabel if you picked the wrong unit: every weight and goal keeps its number and is written in lb instead. Convert if your gym uses lb: every weight and goal is rewritten in lb."),
        (UnitChange.distances(.mi), "Write distances in miles?", "Relabel as miles",
         "Relabel if you picked the wrong unit: every speed and goal keeps its number and is written in mph instead. Convert if your gym uses mph: every speed and goal is rewritten in mph."),
        (UnitChange.weights(.kg), "Write weights in kg?", "Relabel as kg",
         "Relabel if you picked the wrong unit: every weight and goal keeps its number and is written in kg instead. Convert if your gym uses kg: every weight and goal is rewritten in kg."),
    ])
    func theQuestionSaysARelabelMovesNoNumber(change: UnitChange, title: String, relabel: String, message: String) {
        #expect(change.title == title)
        #expect(change.relabelLabel == relabel)
        #expect(change.message == message)
    }

    @Test("Picking the unit already held asks nothing and changes nothing")
    func pickingTheHeldUnitAsksNothing() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.lb)
        fixture.distanceUnit(.mi)
        fixture.log(fixture.exercise("Squat"), reps: 5, weight: 225)
        fixture.interval(fixture.erg("Treadmill", kind: .freeWeight))
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(weightsTo: .lb)
        #expect(settings.unitChange == nil)
        settings.change(distancesTo: .mi)
        #expect(settings.unitChange == nil)
    }

    @Test("Answering no changes neither the unit nor any number")
    func cancellingChangesNothing() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.kg)
        fixture.log(fixture.exercise("Squat"), reps: 5, weight: 100)
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(weightsTo: .lb)
        settings.cancelUnitChange()

        #expect(settings.unitChange == nil)
        #expect(settings.weightUnit == .kg)
        #expect(WeightUnit.stored(in: fixture.defaults) == .kg)
    }

    // MARK: - What is on a scale

    @Test("A lift or a strength goal at either scope puts weights on the scale, so a change asks", arguments: [
        "a lift", "an exercise's goal", "a machine's goal",
    ])
    func weightsOnTheScaleAsk(holding row: String) throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.kg)
        switch row {
        case "a lift":
            fixture.log(fixture.exercise("Squat"), reps: 5, weight: 100)
        case "an exercise's goal":
            GoalScope.exercise(fixture.exercise("Squat")).set(reps: 5, weight: 120)
        default:
            let press = fixture.exercise("Leg press", kind: .gymBound)
            GoalScope.machine(fixture.machine(for: press, at: fixture.gym("Fitness X"))).set(reps: 10, weight: 180)
        }
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(weightsTo: .lb)

        #expect(settings.unitChange == .weights(.lb))
        #expect(WeightUnit.stored(in: fixture.defaults) == .kg)
    }

    @Test("A speed erg's interval or speed goal at either scope puts distances on the scale, so a change asks", arguments: [
        "an interval", "an erg's goal", "a machine's goal",
    ])
    func distancesOnTheScaleAsk(holding row: String) throws {
        let fixture = try LibraryFixture()
        fixture.distanceUnit(.km)
        switch row {
        case "an interval":
            fixture.interval(fixture.erg("Treadmill", kind: .freeWeight))
        case "an erg's goal":
            GoalScope.exercise(fixture.erg("Treadmill", kind: .freeWeight)).set(zone: 2, duration: 1800, intensity: 10, incline: 0)
        default:
            let treadmill = fixture.erg("Treadmill")
            GoalScope.machine(fixture.machine(for: treadmill, at: fixture.gym("Fitness X"))).set(zone: 2, duration: 1800, intensity: 10, incline: 0)
        }
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(distancesTo: .mi)

        #expect(settings.unitChange == .distances(.mi))
        #expect(DistanceUnit.stored(in: fixture.defaults) == .km)
    }

    // MARK: - Nothing on the scale yet

    @Test("With no speed erg entry or goal, the distance unit changes without asking", arguments: [
        "nothing", "a lift", "a rower's intervals and goal",
    ])
    func distancesChangeWithoutAsking(holding library: String) throws {
        let fixture = try LibraryFixture()
        fixture.distanceUnit(.km)
        switch library {
        case "nothing": break
        case "a lift": fixture.log(fixture.exercise("Squat"), reps: 5, weight: 100)
        default:
            let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
            fixture.interval(rower, intensity: 120)
            GoalScope.exercise(rower).set(zone: 2, duration: 1800, intensity: 118, incline: nil)
        }
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(distancesTo: .mi)

        #expect(settings.unitChange == nil)
        #expect(settings.distanceUnit == .mi)
        #expect(DistanceUnit.stored(in: fixture.defaults) == .mi)
    }

    @Test("With no strength entry or goal, the weight unit changes without asking", arguments: [
        "nothing", "an exercise never logged", "a speed erg's intervals",
    ])
    func weightsChangeWithoutAsking(holding library: String) throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.kg)
        switch library {
        case "nothing": break
        case "an exercise never logged": fixture.exercise("Squat")
        default: fixture.interval(fixture.erg("Treadmill", kind: .freeWeight))
        }
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(weightsTo: .lb)

        #expect(settings.unitChange == nil)
        #expect(settings.weightUnit == .lb)
        #expect(WeightUnit.stored(in: fixture.defaults) == .lb)
    }
}
