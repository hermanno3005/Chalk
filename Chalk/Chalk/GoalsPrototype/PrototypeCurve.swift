import Charts
import SwiftUI

// PROTOTYPE — a copy of `StrengthCurve` with two things the shipping one does not have:
// an optional goal mark, and a ghost that can be switched off. Copied rather than
// edited so main's curve is untouched by throwaway parameters.
struct PrototypeCurve: View {
    let curve: RepMaxCurve
    let selectedReps: Int
    /// Drawn only by variant A. The other variants pass `nil` and leave the chart alone.
    let goal: PrototypeGoal?
    let isReached: Bool
    let showGhost: Bool
    let onSelect: (Int?) -> Void

    static let height: CGFloat = 150

    var body: some View {
        Chart {
            if showGhost {
                ForEach(ghost) { point in
                    LineMark(
                        x: .value("Reps", point.reps),
                        y: .value("Ghost", point.weight),
                        series: .value("Series", "ghost")
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 5]))
                    .foregroundStyle(Color.secondary.opacity(0.55))
                }
            }

            ForEach(best) { point in
                LineMark(
                    x: .value("Reps", point.reps),
                    y: .value("Rep-max", point.weight),
                    series: .value("Series", "best")
                )
                .interpolationMethod(.stepEnd)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.accentColor)

                PointMark(
                    x: .value("Reps", point.reps),
                    y: .value("Rep-max", point.weight)
                )
                .symbolSize(point.reps == selectedReps ? 90 : 22)
                .foregroundStyle(Color.accentColor)
            }

            if let goal {
                // A rule the full width of the plot at the goal weight, plus a hollow
                // point at the rep count it was named for. Orange so it cannot be read
                // as either the curve or the ghost.
                RuleMark(y: .value("Goal", goal.weight))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(goalColour)
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text(isReached ? "Reached" : "Goal \(goal.weight.kilogramsText)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(goalColour)
                    }

                PointMark(
                    x: .value("Reps", goal.reps),
                    y: .value("Goal", goal.weight)
                )
                .symbol {
                    Circle()
                        .strokeBorder(goalColour, lineWidth: 2)
                        .frame(width: 11, height: 11)
                }
            }

            RuleMark(x: .value("Reps", selectedReps))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.secondary.opacity(0.4))
                .zIndex(-1)
        }
        .chartXScale(
            domain: RepMaxCurve.repRange,
            range: .plotDimension(startPadding: 10, endPadding: 10)
        )
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: [1, 3, 5, 8, 12]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let reps = value.as(Int.self) { Text("\(reps)") }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
        }
        .chartXSelection(value: Binding<Int?>(get: { selectedReps }, set: { onSelect($0) }))
        .frame(height: Self.height)
    }

    private var goalColour: Color { isReached ? .secondary : .orange }

    private var best: [CurvePoint] { Self.points(curve.best) }
    private var ghost: [CurvePoint] { showGhost ? Self.points(curve.ghost) : [] }

    private static func points(_ weights: [Int: Double]) -> [CurvePoint] {
        RepMaxCurve.repRange.compactMap { reps in
            weights[reps].map { CurvePoint(reps: reps, weight: $0) }
        }
    }

    /// The honest cost of variant A, left visible rather than hidden: a goal drawn on
    /// the chart is drawn data, so the y axis has to frame it, and a far goal squashes
    /// the staircase it was meant to be read against.
    private var yDomain: ClosedRange<Double> {
        var weights = best.map(\.weight) + ghost.map(\.weight)
        if let goal { weights.append(goal.weight) }
        guard let low = weights.min(), let high = weights.max() else { return 0...1 }
        let padding = max((high - low) * 0.12, max(high * 0.05, 1))
        return (low - padding)...(high + padding)
    }

    private struct CurvePoint: Identifiable {
        let reps: Int
        let weight: Double
        var id: Int { reps }
    }
}
