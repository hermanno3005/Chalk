import Foundation
import SwiftData
import Testing

@testable import Chalk

/// Converting a unit on Settings (SPEC §15.2, ADR-0009): every stored number on the scale
/// is rewritten onto the other one, goals included, rounded to **0.5 kg, 1 lb or 0.1 km/h
/// or mph**, nearest step with ties up, and never to the stepper grid. It is one-way, and
/// a backup is how you take it back.
@Suite("Convert")
struct ConvertTests {

    // MARK: - On Settings

    @Test("A library on kg converted to lb rewrites every lift and strength goal, and nothing else")
    func convertingKilogramsToPounds() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.kg)
        let setAt = Date.days(ago: 30)
        let squat = fixture.exercise("Squat")
        fixture.log(squat, reps: 5, weight: 100)
        fixture.log(squat, reps: 8, weight: 52.5)
        GoalScope.exercise(squat).set(reps: 5, weight: 120, at: setAt)
        let press = fixture.exercise("Leg press", kind: .gymBound)
        let machine = fixture.machine(for: press, at: fixture.gym("Fitness X"))
        fixture.log(machine, reps: 10, weight: 180)
        GoalScope.machine(machine).set(reps: 10, weight: 200, at: setAt)
        fixture.interval(fixture.erg("Treadmill", kind: .freeWeight), intensity: 9.3, incline: 1)
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(weightsTo: .lb)
        settings.askToConvert()

        #expect(settings.unitChange == nil)
        #expect(settings.convertConfirmation != nil)
        #expect(WeightUnit.stored(in: fixture.defaults) == .kg)

        settings.convert()

        #expect(settings.convertConfirmation == nil)
        #expect(settings.weightUnit == .lb)
        #expect(WeightUnit.stored(in: fixture.defaults) == .lb)
        let store = try fixture.afterRelaunch()
        let entries = try store.fetch(FetchDescriptor<Entry>())
        #expect(entries.filter(\.isALift).map(\.weight).sorted() == [116, 220, 397])
        #expect(entries.filter(\.isALift).map(\.reps).sorted() == [5, 8, 10])
        #expect(entries.filter(\.isAnInterval).map(\.intensity) == [9.3])
        #expect(entries.filter(\.isAnInterval).map(\.incline) == [1])
        let exercises = try store.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Squat" }))
        #expect(exercises.map(\.goalWeight) == [265])
        #expect(exercises.map(\.goalSetAt) == [setAt])
        let machines = try store.fetch(FetchDescriptor<Machine>())
        #expect(machines.map(\.goalWeight) == [441])
        #expect(machines.map(\.goalReps) == [10])
    }

    @Test("A convert reopens the app on the converted library, as a restore does, since every screen behind holds the old rows")
    func aConvertReopensTheLibrary() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        fixture.weightUnit(.kg)
        fixture.distanceUnit(.km)
        fixture.log(fixture.exercise("Squat"), reps: 5, weight: 100)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 12.0, incline: 1, average: 164, peak: 170)
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(distancesTo: .mi)
        settings.askToConvert()
        #expect(!settings.converted)
        settings.convert()

        #expect(settings.converted)
        // What the reopen does: the library and the screens over it read a fresh context.
        let reopened = try fixture.afterRelaunch()
        let erg = try #require(try reopened.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == "Treadmill" })).first)
        let detail = ErgDetailModel(erg: erg, context: reopened, gyms: GymsModel(context: reopened, defaults: fixture.defaults), defaults: fixture.defaults) {}
        #expect(detail.readout?.intensity.decimalPoint == "7.5 mph")
        #expect(LibraryModel(context: reopened, defaults: fixture.defaults).resume?.text() == "5 × 100 kg · today")
    }

    @Test("A convert answered no reopens nothing")
    func aConvertNotMadeReopensNothing() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.kg)
        fixture.log(fixture.exercise("Squat"), reps: 5, weight: 100)
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(weightsTo: .lb)
        settings.askToConvert()
        settings.cancelConvert()

        #expect(!settings.converted)
    }

    @Test("A library on lb converted to kg rewrites every lift and strength goal")
    func convertingPoundsToKilograms() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.lb)
        let squat = fixture.exercise("Squat")
        fixture.log(squat, reps: 5, weight: 225)
        fixture.log(squat, reps: 5, weight: 135)
        GoalScope.exercise(squat).set(reps: 5, weight: 315)
        let press = fixture.exercise("Leg press", kind: .gymBound)
        let machine = fixture.machine(for: press, at: fixture.gym("Fitness X"))
        GoalScope.machine(machine).set(reps: 10, weight: 45)
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(weightsTo: .kg)
        settings.askToConvert()
        settings.convert()

        #expect(settings.weightUnit == .kg)
        let store = try fixture.afterRelaunch()
        #expect(try store.fetch(FetchDescriptor<Entry>()).map(\.weight).sorted() == [61, 102])
        #expect(try store.fetch(FetchDescriptor<Exercise>()).compactMap(\.goalWeight) == [143])
        #expect(try store.fetch(FetchDescriptor<Machine>()).map(\.goalWeight) == [20.5])
    }

    @Test("A library on km converted to miles rewrites every speed erg's interval and speed goal, and nothing else")
    func convertingKilometresToMiles() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        fixture.weightUnit(.kg)
        fixture.distanceUnit(.km)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, duration: 360, intensity: 12.0, incline: 1.5, average: 164, peak: 170)
        fixture.interval(treadmill, intensity: 9.3)
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 12.0, incline: 1)
        let bike = fixture.erg("Bike")
        let machine = fixture.machine(for: bike, at: fixture.gym("Fitness X"))
        fixture.interval(bike, machine: machine, intensity: 20.0)
        GoalScope.machine(machine).set(zone: 2, duration: 1800, intensity: 25.0, incline: 0)
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        fixture.interval(rower, intensity: 120)
        GoalScope.exercise(rower).set(zone: 2, duration: 1800, intensity: 118, incline: nil)
        let squat = fixture.exercise("Squat")
        fixture.log(squat, reps: 5, weight: 100)
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(distancesTo: .mi)
        settings.askToConvert()
        settings.convert()

        #expect(settings.distanceUnit == .mi)
        #expect(DistanceUnit.stored(in: fixture.defaults) == .mi)
        #expect(WeightUnit.stored(in: fixture.defaults) == .kg)
        let store = try fixture.afterRelaunch()
        let entries = try store.fetch(FetchDescriptor<Entry>())
        #expect(entries.filter { $0.exercise?.name != "Rower" && $0.isAnInterval }.map(\.intensity).sorted() == [5.8, 7.5, 12.4])
        #expect(entries.filter { $0.exercise?.name == "Rower" }.map(\.intensity) == [120])
        #expect(entries.filter(\.isALift).map(\.weight) == [100])
        #expect(entries.filter { $0.duration == 360 && $0.incline == 1.5 }.map(\.averageHeartRate) == [164])
        let ergs = try store.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        #expect(ergs.map(\.goalIntensity) == [nil, 118, nil, 7.5])
        #expect(ergs.map(\.goalIncline) == [nil, nil, nil, 1])
        #expect(try store.fetch(FetchDescriptor<Machine>()).map(\.goalIntensity) == [15.5])
        #expect(fixture.heldZones()?.lowerBounds == [117, 140, 158, 170])
    }

    @Test("A library on miles converted to km rewrites every speed erg's interval and speed goal")
    func convertingMilesToKilometres() throws {
        let fixture = try LibraryFixture()
        fixture.distanceUnit(.mi)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, intensity: 7.5)
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 6.0, incline: 1)
        let bike = fixture.erg("Bike")
        GoalScope.machine(fixture.machine(for: bike, at: fixture.gym("Fitness X"))).set(zone: 2, duration: 1800, intensity: 15.5, incline: 0)
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(distancesTo: .km)
        settings.askToConvert()
        settings.convert()

        #expect(settings.distanceUnit == .km)
        let store = try fixture.afterRelaunch()
        #expect(try store.fetch(FetchDescriptor<Entry>()).map(\.intensity) == [12.1])
        #expect(try store.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])).map(\.goalIntensity) == [nil, 9.7])
        #expect(try store.fetch(FetchDescriptor<Machine>()).map(\.goalIntensity) == [24.9])
    }

    // MARK: - The confirmation

    @Test("The confirmation counts every lift and strength goal at both scopes it converts")
    func theConfirmationCountsLiftsAndGoals() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.kg)
        let squat = fixture.exercise("Squat")
        fixture.log(squat, reps: 5, weight: 100)
        fixture.log(squat, reps: 5, weight: 102.5)
        GoalScope.exercise(squat).set(reps: 5, weight: 120)
        let press = fixture.exercise("Leg press", kind: .gymBound)
        GoalScope.machine(fixture.machine(for: press, at: fixture.gym("Fitness X"))).set(reps: 10, weight: 180)
        fixture.interval(fixture.erg("Treadmill", kind: .freeWeight))
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(weightsTo: .lb)
        settings.askToConvert()

        #expect(settings.pendingConvert?.change.convertTitle == "Convert weights to lb?")
        #expect(settings.convertConfirmation == "Converts 2 entries and 2 goals to lb, rounded to the nearest pound. This can't be undone, except by restoring a backup.")
    }

    @Test("The confirmation counts every speed erg interval and speed goal, and no other erg's")
    func theConfirmationCountsSpeedsAndGoals() throws {
        let fixture = try LibraryFixture()
        fixture.distanceUnit(.mi)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, intensity: 7.5)
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 6.0, incline: 1)
        let rower = fixture.erg("Rower", unit: .split, kind: .freeWeight)
        fixture.interval(rower, intensity: 120)
        GoalScope.exercise(rower).set(zone: 2, duration: 1800, intensity: 118, incline: nil)
        fixture.log(fixture.exercise("Squat"), reps: 5, weight: 100)
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(distancesTo: .km)
        settings.askToConvert()

        #expect(settings.pendingConvert?.change.convertTitle == "Convert distances to km?")
        #expect(settings.convertConfirmation == "Converts 1 entry and 1 goal to km/h, rounded to the nearest 0.1 km/h. This can't be undone, except by restoring a backup.")
    }

    @Test("The confirmation leaves out a side with nothing to count, and names each grid", arguments: [
        (UnitChange.weights(.kg), "goals", "Converts 1 goal to kg, rounded to the nearest half kilogram."),
        (.weights(.lb), "entries", "Converts 1,240 entries to lb, rounded to the nearest pound."),
        (.distances(.mi), "goals", "Converts 1 goal to mph, rounded to the nearest 0.1 mph."),
        (.distances(.km), "entries", "Converts 1,240 entries to km/h, rounded to the nearest 0.1 km/h."),
    ])
    func theConfirmationLeavesOutAnEmptySide(change: UnitChange, holding: String, expected: String) throws {
        let fixture = try LibraryFixture()
        let isWeight = if case .weights = change { true } else { false }
        if isWeight {
            fixture.weightUnit(change == .weights(.kg) ? .lb : .kg)
            let squat = fixture.exercise("Squat")
            if holding == "goals" {
                GoalScope.exercise(squat).set(reps: 5, weight: 225)
            } else {
                for _ in 0..<1240 { fixture.log(squat, reps: 5, weight: 100) }
            }
        } else {
            fixture.distanceUnit(change == .distances(.mi) ? .km : .mi)
            let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
            if holding == "goals" {
                GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 12, incline: 1)
            } else {
                for _ in 0..<1240 { fixture.interval(treadmill) }
            }
        }
        try fixture.save()

        let convert = try Convert(change, over: fixture.store.container, defaults: fixture.defaults)

        #expect(convert.confirmation(locale: Locale(identifier: "en_GB")) == expected + " This can't be undone, except by restoring a backup.")
    }

    @Test("The question offers a convert beside the relabel", arguments: [
        (UnitChange.weights(.lb), "Convert to lb…"),
        (.distances(.mi), "Convert to miles…"),
    ])
    func theQuestionOffersAConvert(change: UnitChange, convert: String) {
        #expect(change.convertLabel == convert)
    }

    @Test("Answering the confirmation no changes neither the unit nor any number")
    func cancellingAConvertChangesNothing() throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.kg)
        fixture.log(fixture.exercise("Squat"), reps: 5, weight: 100)
        try fixture.save()
        let settings = fixture.settingsModel()

        settings.change(weightsTo: .lb)
        settings.askToConvert()
        settings.cancelConvert()

        #expect(settings.pendingConvert == nil)
        #expect(settings.weightUnit == .kg)
        #expect(WeightUnit.stored(in: fixture.defaults) == .kg)
        #expect(try fixture.afterRelaunch().fetch(FetchDescriptor<Entry>()).map(\.weight) == [100])
    }

    // MARK: - All or nothing

    @Test("A convert that fails before the commit leaves every number and the unit as they were", arguments: [
        UnitChange.weights(.lb), .distances(.mi),
    ])
    func aFailureBeforeTheCommitChangesNothing(change: UnitChange) throws {
        let fixture = try LibraryFixture()
        fixture.weightUnit(.kg)
        fixture.distanceUnit(.km)
        let squat = fixture.exercise("Squat")
        fixture.log(squat, reps: 5, weight: 100)
        GoalScope.exercise(squat).set(reps: 5, weight: 120)
        let treadmill = fixture.erg("Treadmill", kind: .freeWeight)
        fixture.interval(treadmill, intensity: 12.0)
        GoalScope.exercise(treadmill).set(zone: 4, duration: 360, intensity: 12.5, incline: 1)
        try fixture.save()

        let convert = try Convert(change, over: fixture.store.container, defaults: fixture.defaults)
        #expect(throws: Halfway.self) {
            try convert.convert { throw Halfway() }
        }

        #expect(WeightUnit.stored(in: fixture.defaults) == .kg)
        #expect(DistanceUnit.stored(in: fixture.defaults) == .km)
        let store = try fixture.afterRelaunch()
        #expect(try store.fetch(FetchDescriptor<Entry>()).map(\.weight).sorted() == [0, 100])
        #expect(try store.fetch(FetchDescriptor<Entry>()).map(\.intensity).sorted() == [0, 12.0])
        let exercises = try store.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        #expect(exercises.map(\.goalWeight) == [120, nil])
        #expect(exercises.map(\.goalIntensity) == [nil, 12.5])
    }

    private struct Halfway: Error {}

    // MARK: - The grid

    @Test("A weight converts to the nearest step of the other scale", arguments: [
        (WeightUnit.kg, 100.0, WeightUnit.lb, 220.0),
        (.lb, 225, .kg, 102),
        (.lb, 135, .kg, 61),
        (.kg, 61, .lb, 134),
        (.kg, 52.5, .lb, 116),
        (.lb, 45, .kg, 20.5),
    ])
    func aWeightConverts(from: WeightUnit, weight: Double, to: WeightUnit, converted: Double) {
        #expect(from.converted(weight, to: to) == converted)
    }

    @Test("A speed converts to the nearest tenth of the other scale", arguments: [
        (DistanceUnit.km, 12.0, DistanceUnit.mi, 7.5),
        (.mi, 7.5, .km, 12.1),
        (.km, 9.3, .mi, 5.8),
        (.mi, 6.0, .km, 9.7),
    ])
    func aSpeedConverts(from: DistanceUnit, speed: Double, to: DistanceUnit, converted: Double) {
        #expect(from.converted(speed, to: to) == converted)
    }

    @Test("A tie rounds up")
    func aTieRoundsUp() {
        #expect(WeightUnit.kg.onConvertGrid(60.25) == 60.5)
        #expect(WeightUnit.lb.onConvertGrid(220.5) == 221)
        #expect(DistanceUnit.km.onConvertGrid(7.25) == 7.3)
        #expect(DistanceUnit.mi.onConvertGrid(7.35) == 7.4)
    }

    @Test("A converted tenth is the Double nearest the decimal")
    func aTenthIsTheNearestDouble() {
        // `n * 0.1` would write 7.000000000000001 for 70 tenths and 0.30000000000000004 for 3.
        #expect(DistanceUnit.km.onConvertGrid(6.99) == 7.0)
        #expect(DistanceUnit.mi.onConvertGrid(0.31) == 0.3)
    }

    // MARK: - There and back

    @Test("Every kg weight comes home exactly, on either kg grid")
    func everyKilogramWeightComesHome() {
        for halves in 1...2000 {
            let weight = Double(halves) / 2
            #expect(WeightUnit.lb.converted(WeightUnit.kg.converted(weight, to: .lb), to: .kg) == weight)
        }
    }

    @Test("19 of the 201 weights on the 5 lb grid up to 1000 lb come back a pound off, 135 lb among them")
    func someLbWeightsComeBackAPoundOff() {
        let weights = (0...200).map { Double($0) * 5 }
        let home = weights.map { WeightUnit.kg.converted(WeightUnit.lb.converted($0, to: .kg), to: .lb) }

        #expect(zip(weights, home).count { $0 != $1 } == 19)
        #expect(zip(weights, home).allSatisfy { abs($0 - $1) <= 1 })
        #expect(WeightUnit.lb.converted(135, to: .kg) == 61)
        #expect(WeightUnit.kg.converted(61, to: .lb) == 134)
    }

    @Test("Every mph speed comes home exactly")
    func everyMphSpeedComesHome() {
        for tenths in 1...400 {
            let speed = Double(tenths) / 10
            #expect(DistanceUnit.km.converted(DistanceUnit.mi.converted(speed, to: .km), to: .mi) == speed)
        }
    }

    @Test("83 of the 220 km/h speeds from 3.0 to 24.9 come back 0.1 off")
    func someKmhSpeedsComeBackATenthOff() {
        let speeds = (30...249).map { Double($0) / 10 }
        let home = speeds.map { DistanceUnit.mi.converted(DistanceUnit.km.converted($0, to: .mi), to: .km) }

        #expect(zip(speeds, home).count { $0 != $1 } == 83)
        #expect(zip(speeds, home).allSatisfy { abs($0 - $1) < 0.11 })
    }
}
