import Accessibility
import SwiftUI

/// A chart as VoiceOver plays and says it (SPEC §15.6): its axes with the words each value
/// is said in, and its series as tones. A plain value built from the derivation's own
/// numbers, so what is heard is what is drawn; `makeChartDescriptor()` hands it to the
/// system as an `AXChartDescriptor`.
struct AudioGraph: AXChartDescriptorRepresentable {

    struct Axis {
        let title: String
        let range: ClosedRange<Double>
        /// A value on this axis in words: `5 reps`, `102.5 pounds`.
        let says: (Double) -> String
    }

    struct Point: Equatable {
        let x: Double
        let y: Double
        /// What else VoiceOver says at this point: `164 beats per minute, 12 entries`.
        var label: String?
    }

    struct Series: Equatable {
        let name: String
        /// A line heard as one sweep rather than a tone per point.
        let isContinuous: Bool
        let points: [Point]
    }

    let title: String
    let summary: String?
    let x: Axis
    let y: Axis
    let series: [Series]

    func makeChartDescriptor() -> AXChartDescriptor {
        AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: Self.descriptor(x),
            yAxis: Self.descriptor(y),
            series: series.map { series in
                AXDataSeriesDescriptor(
                    name: series.name,
                    isContinuous: series.isContinuous,
                    dataPoints: series.points.map { AXDataPoint(x: $0.x, y: $0.y, label: $0.label) }
                )
            }
        )
    }

    private static func descriptor(_ axis: Axis) -> AXNumericDataAxisDescriptor {
        AXNumericDataAxisDescriptor(title: axis.title, range: axis.range, gridlinePositions: [], valueDescriptionProvider: axis.says)
    }
}

// MARK: - The strength curve

extension AudioGraph {

    /// The strength curve (SPEC §5.2): the rep-max staircase, one tone per proven rep count
    /// and nothing where a cell is unproven, then the ghost as one sweep across the axis,
    /// said in the weight unit. The goal is never drawn on the chart (§12.4), so it is only
    /// said, in the summary, as the line under the number says it.
    init(curve: RepMaxCurve, weightUnit: WeightUnit, goal: Goal?) {
        let points = { (weights: [Int: Double]) in
            RepMaxCurve.repRange.compactMap { reps in weights[reps].map { Point(x: Double(reps), y: $0) } }
        }
        let best = points(curve.best)
        let ghost = points(curve.ghost)
        // Framed to both, as the chart is: the ghost is drawn data too.
        let weights = (best + ghost).map(\.y)
        self.init(
            title: "Strength curve",
            summary: [
                "Your heaviest weight at each rep count from 1 to 12.",
                "The projection behind it is guidance only, never a weight you have lifted.",
                goal.map { "\($0.spokenLine(in: weightUnit))." },
            ].compactMap(\.self).joined(separator: " "),
            x: Axis(
                title: "Reps",
                range: Double(RepMaxCurve.repRange.lowerBound)...Double(RepMaxCurve.repRange.upperBound),
                says: { Spoken.reps(Int($0.rounded())) }
            ),
            y: Axis(
                title: "Weight",
                range: (weights.min() ?? 0)...(weights.max() ?? 1),
                says: weightUnit.spokenText
            ),
            series: [
                // A tone per rep count: the staircase holds each value to the next, and
                // nothing between two counts is a weight you lifted.
                Series(name: "Rep-max", isContinuous: false, points: best),
                Series(name: "Projection", isContinuous: true, points: ghost),
            ]
        )
    }
}

// MARK: - The zone line

extension AudioGraph {

    /// One zone's line (SPEC §13.8): one sweep through the durations done, said in the
    /// erg's unit and, on a speed erg, the distance unit, each point with the heart rate and
    /// entry count its rows show. **A split is played upside down**, as it is drawn, so
    /// harder is higher on every erg. The goal is said in the summary, as strength's is.
    init(
        zoneLine points: [ZoneLine.Point],
        unit: ErgUnit,
        distanceUnit: DistanceUnit,
        zone: Int,
        incline: Double?,
        goal: EnduranceGoal?
    ) {
        let line = points.map { point in
            Point(
                x: Double(point.duration),
                y: point.intensity * unit.hardnessSign,
                label: "\(Spoken.heartRate(point.averageHeartRate)), \(Spoken.count(point.entryCount, "entry"))"
            )
        }
        let values = line.map(\.y)
        let held = "What you held in zone \(zone) at each duration you have done, up to 20 minutes"
        self.init(
            title: "Zone \(zone) line",
            summary: [
                unit.hasIncline ? "\(held), at \(Spoken.incline(incline ?? 0))." : "\(held).",
                goal.map { "\($0.spokenLine)." },
            ].compactMap(\.self).joined(separator: " "),
            x: Axis(
                title: "Duration",
                range: 0...Double(ZoneLine.axisEnd),
                says: { Spoken.duration(Int($0.rounded())) }
            ),
            y: Axis(
                title: unit.spokenTitle,
                range: (values.min() ?? 0)...(values.max() ?? 1),
                says: { EnduranceText.spokenIntensity($0 * unit.hardnessSign, unit, distanceUnit) }
            ),
            series: [Series(name: "Zone \(zone)", isContinuous: true, points: line)]
        )
    }
}

extension ErgUnit {
    /// What the audio graph calls the intensity axis.
    var spokenTitle: String {
        switch self {
        case .speed: "Speed"
        case .watts: "Power"
        case .split: "Split"
        case .level: "Level"
        }
    }
}
