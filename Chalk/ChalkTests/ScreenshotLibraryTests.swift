import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The library the App Store screenshots are taken over (SPEC §15.6). It goes in through
/// a restore, so it has to be a backup Chalk accepts, and it has to show what the
/// screenshots are for: a full curve, a goal still out of reach, and a line in every zone.
@Suite("Screenshot library")
struct ScreenshotLibraryTests {

    static let now = Date(timeIntervalSinceReferenceDate: 815_000_000)

    @Test("It restores, and the same day makes the same file")
    func restores() throws {
        let file = try ScreenshotLibrary.backup(now: Self.now).encoded()
        #expect(try ScreenshotLibrary.backup(now: Self.now).encoded() == file)

        let phone = try LibraryFixture()
        try Restore(reading: file, over: phone.store.container, defaults: phone.defaults).replace()
        let counts = try LibraryCounts(ModelContext(phone.store.container))
        #expect(counts.exercises == 12)
        #expect(counts.ergs == 4)
        #expect(counts.gyms == 1)
    }

    @Test("Bench Press proves every rep count, was logged today, and its goal is still out of reach")
    func benchPress() throws {
        let bench = try #require(ScreenshotLibrary.backup(now: Self.now).exercises.first { $0.name == "Bench Press" })
        let entries = bench.allEntries
        for reps in 1...12 {
            #expect(entries.contains { $0.reps >= reps })
        }
        #expect(entries.map(\.date).max()! <= Self.now)
        #expect(Calendar.current.isDate(entries.map(\.date).max()!, inSameDayAs: Self.now))

        let goalReps = try #require(bench.goal.goalReps)
        let best = entries.filter { $0.reps >= goalReps }.map(\.weight).max()!
        #expect(best < bench.goal.goalWeight!)
    }

    @Test("The treadmill has a line in every zone at its goal's incline, and the goal is out of reach")
    func treadmill() throws {
        let treadmill = try #require(ScreenshotLibrary.backup(now: Self.now).exercises.first { $0.name == "Treadmill" })
        let machine = try #require(treadmill.machines.first)
        let zones = try #require(HeartRateZones(lowerBounds: ScreenshotLibrary.zones))
        for zone in 2...5 {
            let durations = Set(machine.entries.filter { zones.zone(of: $0.averageHeartRate) == zone }.map(\.duration))
            #expect(durations.count >= 2, "Z\(zone) needs two durations to draw a line")
        }

        let goal = machine.goal
        let atGoal = machine.entries
            .filter { $0.duration == goal.goalDuration && zones.zone(of: $0.averageHeartRate) == goal.goalZone }
            .sorted { $0.date > $1.date }
            .prefix(10)
        let mean = atGoal.map(\.intensity).reduce(0, +) / Double(atGoal.count)
        #expect(mean < goal.goalIntensity!)
    }
}
