import Foundation
import Testing

@testable import Chalk

/// The audio graphs behind the strength curve and the zone line (SPEC §15.6): what
/// VoiceOver plays and says for each chart, built from the derivation's own values and
/// spoken in the weight and distance unit.
@Suite("Audio graphs")
struct AudioGraphTests {

    private let decimal = WeightText.decimalSeparator

    // MARK: - The strength curve

    @Test("The curve plays each proven rep count, and says its weight in the weight unit")
    func theCurveSeries() throws {
        let curve = RepMaxCurve(entries: [
            Entry(reps: 1, weight: 225),
            Entry(reps: 5, weight: 185),
        ])

        let graph = AudioGraph(curve: curve, weightUnit: .lb, goal: nil)

        let best = try #require(graph.series.first { $0.name == "Rep-max" })
        #expect(best.points.map(\.x) == [1, 2, 3, 4, 5])
        #expect(best.points.map(\.y) == [225, 185, 185, 185, 185])

        #expect(graph.x.title == "Reps")
        #expect(graph.x.range == 1...12)
        #expect(graph.x.says(1) == "1 rep")
        #expect(graph.x.says(5) == "5 reps")
        #expect(graph.y.title == "Weight")
        #expect(graph.y.says(185) == "185 pounds")
        #expect(graph.y.says(102.5) == "102\(decimal)5 pounds")
    }

    @Test("The ghost plays as a projection across all twelve rep counts, inside the weight axis")
    func theGhostSeries() throws {
        // One 100 kg × 5: an Epley 1RM of 116.67, so 112.90 at 1 rep and 83.33 at 12.
        let curve = RepMaxCurve(entries: [Entry(reps: 5, weight: 100)])

        let graph = AudioGraph(curve: curve, weightUnit: .kg, goal: nil)

        let ghost = try #require(graph.series.first { $0.name == "Projection" })
        #expect(ghost.isContinuous)
        #expect(ghost.points.map(\.x) == Array(1...12).map(Double.init))
        #expect(abs(ghost.points[0].y - 112.90) < 0.01)
        #expect(abs(ghost.points[4].y - 100) < 0.01)
        #expect(abs(ghost.points[11].y - 83.33) < 0.01)
        #expect(abs(graph.y.range.lowerBound - 83.33) < 0.01)
        #expect(abs(graph.y.range.upperBound - 112.90) < 0.01)
        #expect(graph.series.first { $0.name == "Rep-max" }?.isContinuous == false)
    }

    @Test("The summary says what the curve and the projection are, and the goal where there is one")
    func theCurveSummary() {
        let entries = [Entry(reps: 5, weight: 100)]
        let curve = RepMaxCurve(entries: entries)
        let goal = Goal(reps: 5, weight: 140, setAt: .now, entries: entries)

        let without = AudioGraph(curve: curve, weightUnit: .kg, goal: nil)
        let with = AudioGraph(curve: curve, weightUnit: .kg, goal: goal)

        let curveWords = "Your heaviest weight at each rep count from 1 to 12. The projection behind it is guidance only, never a weight you have lifted."
        #expect(without.summary == curveWords)
        #expect(with.summary == "\(curveWords) Goal 140 kilograms for 5 reps, 40 kilograms to go.")
    }

    // MARK: - The zone line

    private func point(_ duration: Int, _ intensity: Double, bpm: Int = 160, entries: Int = 3) -> ZoneLine.Point {
        ZoneLine.Point(duration: duration, intensity: intensity, averageHeartRate: bpm, entryCount: entries)
    }

    @Test("The zone line plays each duration done, and says a speed in the distance unit")
    func theZoneLineSeries() throws {
        let points = [point(360, 9.3), point(600, 8.8)]

        let graph = AudioGraph(zoneLine: points, unit: .speed, distanceUnit: .mi, zone: 4, incline: 1, goal: nil)

        let line = try #require(graph.series.first)
        #expect(graph.series.count == 1)
        #expect(line.name == "Zone 4")
        #expect(line.isContinuous)
        #expect(line.points.map(\.x) == [360, 600])
        #expect(line.points.map(\.y) == [9.3, 8.8])

        #expect(graph.x.title == "Duration")
        #expect(graph.x.range == 0...1200)
        #expect(graph.x.says(360) == "6 minutes")
        #expect(graph.x.says(90) == "1 minute 30 seconds")
        #expect(graph.x.says(45) == "45 seconds")
        #expect(graph.x.says(0) == "0 seconds")
        #expect(graph.y.title == "Speed")
        #expect(graph.y.says(9.3) == "9\(decimal)3 miles per hour")
        #expect(graph.y.range == 8.8...9.3)

        let km = AudioGraph(zoneLine: points, unit: .speed, distanceUnit: .km, zone: 4, incline: 1, goal: nil)
        #expect(km.y.says(15) == "15\(decimal)0 kilometres per hour")
    }

    @Test("A split plays upside down, so harder is higher, and is said as a split per 500 metres")
    func aSplitPlaysUpsideDown() throws {
        // 1:45.3 at 6:00 is harder than 1:50 at 10:00, so it plays higher.
        let points = [point(360, 105.3), point(600, 110)]

        let graph = AudioGraph(zoneLine: points, unit: .split, distanceUnit: .km, zone: 3, incline: nil, goal: nil)

        let line = try #require(graph.series.first)
        #expect(line.points[0].y > line.points[1].y)
        #expect(graph.y.title == "Split")
        #expect(graph.y.says(line.points[0].y) == "1 minute 45\(decimal)3 seconds per 500 metres")
        #expect(graph.y.says(line.points[1].y) == "1 minute 50 seconds per 500 metres")
        #expect(graph.y.range.contains(line.points[0].y) && graph.y.range.contains(line.points[1].y))
    }

    @Test("Watts and levels are said in words", arguments: [
        (ErgUnit.watts, 220.0, "Power", "220 watts"),
        (ErgUnit.watts, 1.0, "Power", "1 watt"),
        (ErgUnit.level, 12.0, "Level", "level 12"),
    ])
    func wattsAndLevels(unit: ErgUnit, value: Double, title: String, spoken: String) {
        let graph = AudioGraph(zoneLine: [point(360, value)], unit: unit, distanceUnit: .km, zone: 2, incline: nil, goal: nil)

        #expect(graph.y.title == title)
        #expect(graph.y.says(value) == spoken)
    }

    @Test("Each point says its heart rate and how many entries stand behind it")
    func eachPointSaysItsHeartRate() throws {
        let graph = AudioGraph(
            zoneLine: [point(360, 15.1, bpm: 164, entries: 12), point(600, 14.8, bpm: 168, entries: 1)],
            unit: .speed, distanceUnit: .km, zone: 4, incline: 0, goal: nil
        )

        let line = try #require(graph.series.first)
        #expect(line.points.map(\.label) == ["164 beats per minute, 12 entries", "168 beats per minute, 1 entry"])
    }

    @Test("The summary names the zone, a speed erg's incline, and the goal where there is one")
    func theZoneLineSummary() throws {
        // Z4 from 158 bpm: one 15.1 km/h at 6:00, 1 %, against a goal of 15.5 there.
        let zones = try #require(HeartRateZones(lowerBounds: [120, 140, 158, 170]))
        let entries = [Entry(duration: 360, intensity: 15.1, incline: 1, averageHeartRate: 164, peakHeartRate: 170)]
        let speedGoal = EnduranceGoal(
            zone: 4, duration: 360, intensity: 15.5, incline: 1, setAt: .now,
            entries: entries, zones: zones, unit: .speed, distanceUnit: .km
        )
        let wattsGoal = EnduranceGoal(
            zone: 3, duration: 600, intensity: 260, incline: nil, setAt: .now,
            entries: [], zones: zones, unit: .watts, distanceUnit: .km
        )

        let speed = AudioGraph(zoneLine: [point(360, 15.1)], unit: .speed, distanceUnit: .km, zone: 4, incline: 1, goal: speedGoal)
        let watts = AudioGraph(zoneLine: [point(600, 250)], unit: .watts, distanceUnit: .km, zone: 3, incline: nil, goal: wattsGoal)
        let bare = AudioGraph(zoneLine: [point(600, 250)], unit: .watts, distanceUnit: .km, zone: 3, incline: nil, goal: nil)

        #expect(speed.summary == "What you held in zone 4 at each duration you have done, up to 20 minutes, at 1 percent incline. "
            + "Goal 15\(decimal)5 kilometres per hour for 6 minutes in zone 4 at 1 percent incline, 0\(decimal)4 kilometres per hour to go.")
        #expect(watts.summary == "What you held in zone 3 at each duration you have done, up to 20 minutes. "
            + "Goal 260 watts for 10 minutes in zone 3, not held yet.")
        #expect(bare.summary == "What you held in zone 3 at each duration you have done, up to 20 minutes.")
    }
}
