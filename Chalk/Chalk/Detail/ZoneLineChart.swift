import Charts
import SwiftUI

/// One zone's line on the erg detail screen (SPEC §13.8): 150 pt, in the accent colour,
/// a point on every duration done, joined by straight segments.
///
/// **No ghost and no band** — nothing is drawn that you have not held. Drawn only where
/// the zone has a line: the empty and no-line states show text instead, so this view
/// never renders an empty frame.
struct ZoneLineChart: View {
    let points: [ZoneLine.Point]
    let unit: ErgUnit
    let selectedDuration: Int
    /// `chartXSelection` writes `nil` here on lift; the model ignores that and snaps
    /// every real value to a duration done, which is the sticky, snapping scrub.
    let onSelect: (Int?) -> Void

    static let height: CGFloat = 150

    var body: some View {
        Chart {
            ForEach(points, id: \.duration) { point in
                LineMark(
                    x: .value("Duration", point.duration),
                    y: .value("Intensity", plotted(point.intensity))
                )
                // Straight segments: nothing between two points is a number you held,
                // so nothing is smoothed into one.
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.accentColor)

                PointMark(
                    x: .value("Duration", point.duration),
                    y: .value("Intensity", plotted(point.intensity))
                )
                .symbolSize(point.duration == selectedDuration ? 90 : 26)
                .foregroundStyle(Color.accentColor)
            }

            RuleMark(x: .value("Duration", selectedDuration))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.secondary.opacity(0.4))
                .zIndex(-1)
        }
        // **Linear and fixed at 0–20:00 on every erg and zone**, so lines compare and
        // switching zones never rescales the chart under your thumb.
        .chartXScale(
            domain: 0...ZoneLine.axisEnd,
            range: .plotDimension(startPadding: 12, endPadding: 16)
        )
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: [0, 300, 600, 900, 1200]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let seconds = value.as(Int.self) {
                        Text(EnduranceText.clock(seconds))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let plotted = value.as(Double.self) {
                        Text(EnduranceText.intensityNumber(unplotted(plotted), unit))
                    }
                }
            }
        }
        .chartXSelection(value: Binding<Int?>(get: { selectedDuration }, set: { onSelect($0) }))
        .frame(height: Self.height)
        .accessibilityLabel("Zone line")
    }

    /// **A split is plotted upside down**, so harder is up on every erg.
    private func plotted(_ intensity: Double) -> Double {
        intensity * unit.hardnessSign
    }

    private func unplotted(_ value: Double) -> Double {
        value * unit.hardnessSign
    }

    /// Framed to the data with a little air, never anchored at 0, as §5.2's is. One
    /// point gets an arbitrary band around itself: a zero-width domain draws nothing.
    private var yDomain: ClosedRange<Double> {
        let values = points.map { plotted($0.intensity) }
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let padding = max((high - low) * 0.15, max(abs(high) * 0.04, unit.step))
        return (low - padding)...(high + padding)
    }
}
