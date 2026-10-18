import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The erg machine hint (SPEC §13.8, §5.4 carried over): on a gym-bound erg whose machine
/// in scope has no entries, one dimmed line quoting a sibling machine's line.
///
/// The rules an implementer gets subtly wrong: **the same model at another gym beats a
/// more recent sibling**; the quote is **the sibling's line at its most recent valid
/// interval's zone, duration and incline** — the point's mean, not that entry's numbers —
/// and **when that point is not on the line there is no hint**, never another point.
@Suite("Erg machine hint")
struct ErgHintTests {

    @Test("It quotes the sibling's line at the zone, duration and incline of its most recent valid interval")
    func theQuotedPoint() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        let mcFit = fixture.gym("McFit")
        fixture.machine(for: treadmill, at: mcFit, label: "Life Fitness")
        let sibling = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        fixture.interval(treadmill, machine: sibling, duration: 360, intensity: 14.6, incline: 1, average: 162, on: .days(ago: 4))
        fixture.interval(treadmill, machine: sibling, duration: 600, intensity: 13.0, incline: 0, average: 150, on: .days(ago: 2))
        fixture.interval(treadmill, machine: sibling, duration: 360, intensity: 15.4, incline: 1, average: 166, on: .days(ago: 1))
        // Newer, but no heart rate: not a valid interval, so not what the sheet seeds from.
        fixture.interval(treadmill, machine: sibling, duration: 120, intensity: 17.0, average: 0, peak: 0)
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(mcFit)

        let model = fixture.ergDetailModel(for: treadmill, gyms: gyms)

        #expect(model.isEmpty)
        // 15.0 is the point's mean at 6:00 in Z4 at 1 %, not the last entry's 15.4.
        #expect(model.hint?.emptyStateLine.decimalPoint
            == "No entries here — 6:00 in Z4 at 15.0 km/h · 1 % on Technogym Run · Urban Gym")
    }

    @Test("The same model at another gym is preferred over a more recent sibling")
    func theSameModelIsPreferred() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        let mcFit = fixture.gym("McFit")
        fixture.machine(for: treadmill, at: mcFit, label: "Technogym Run")
        let sameModel = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "technogym run")
        let recent = fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Matrix T7")
        fixture.interval(treadmill, machine: sameModel, duration: 360, intensity: 15.0, average: 164, on: .days(ago: 10))
        fixture.interval(treadmill, machine: recent, duration: 600, intensity: 13.0, average: 150, on: .days(ago: 1))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(mcFit)

        let model = fixture.ergDetailModel(for: treadmill, gyms: gyms)

        #expect(model.hint?.emptyStateLine.decimalPoint
            == "No entries here — 6:00 in Z4 at 15.0 km/h on technogym run · Urban Gym")
    }

    @Test("Otherwise it is the most recently used sibling")
    func otherwiseTheMostRecentSibling() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let rower = fixture.erg("Rower", unit: .watts)
        let mcFit = fixture.gym("McFit")
        fixture.machine(for: rower, at: mcFit, label: "WaterRower")
        let older = fixture.machine(for: rower, at: fixture.gym("Urban Gym"), label: "Concept2")
        let recent = fixture.machine(for: rower, at: fixture.gym("FitX"), label: "Matrix")
        fixture.interval(rower, machine: older, duration: 360, intensity: 260, average: 164, on: .days(ago: 10))
        fixture.interval(rower, machine: recent, duration: 600, intensity: 220, average: 150, on: .days(ago: 1))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(mcFit)

        let model = fixture.ergDetailModel(for: rower, gyms: gyms)

        // No incline on a watts erg.
        #expect(model.hint?.emptyStateLine == "No entries here — 10:00 in Z3 at 220 W on Matrix · FitX")
    }

    @Test("When that point has left the sibling's line there is no hint, and no other point instead")
    func theHintVanishesWithItsPoint() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        let mcFit = fixture.gym("McFit")
        fixture.machine(for: treadmill, at: mcFit, label: "Life Fitness")
        let sibling = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        fixture.interval(treadmill, machine: sibling, duration: 360, intensity: 15.0, average: 164, on: .days(ago: 2))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(mcFit)
        let model = fixture.ergDetailModel(for: treadmill, gyms: gyms)
        #expect(model.hint != nil)

        // The sibling's most recent is 25:00 in Z4: stored, never a point on its line.
        fixture.interval(treadmill, machine: sibling, duration: 1500, intensity: 12.0, average: 160, on: .days(ago: 1))
        try fixture.save()
        model.refresh()

        #expect(model.hint == nil)
    }

    @Test("A transferable erg has no hint")
    func noHintOnATransferableErg() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let skiErg = fixture.erg("SkiErg", unit: .watts, kind: .freeWeight)
        let stray = fixture.machine(for: skiErg, at: fixture.gym("Urban Gym"), label: "Concept2")
        fixture.interval(skiErg, machine: stray, duration: 360, intensity: 200, average: 164, on: .days(ago: 1))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(fixture.gym("McFit"))

        let model = fixture.ergDetailModel(for: skiErg, gyms: gyms)

        #expect(model.hint == nil)
    }

    @Test("A machine with entries of its own gets no hint, and the hint never reads another erg")
    func noHintWhereThereIsNothingToSay() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let treadmill = fixture.erg("Treadmill")
        let bike = fixture.erg("Bike", unit: .watts)
        let mcFit = fixture.gym("McFit")
        let here = fixture.machine(for: treadmill, at: mcFit, label: "Technogym Run")
        // Another erg's machine of the same name: never this erg's sibling.
        let otherErgs = fixture.machine(for: bike, at: fixture.gym("Urban Gym"), label: "Technogym Run")
        fixture.interval(bike, machine: otherErgs, duration: 360, intensity: 200, average: 164, on: .days(ago: 1))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(mcFit)
        let model = fixture.ergDetailModel(for: treadmill, gyms: gyms)

        #expect(model.isEmpty)
        #expect(model.hint == nil)

        let sibling = fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Matrix T7")
        fixture.interval(treadmill, machine: sibling, duration: 360, intensity: 15.0, average: 164, on: .days(ago: 2))
        fixture.interval(treadmill, machine: here, duration: 600, intensity: 13.0, average: 150, on: .days(ago: 1))
        try fixture.save()
        model.refresh()

        #expect(!model.isEmpty)
        #expect(model.hint == nil)
    }
}
