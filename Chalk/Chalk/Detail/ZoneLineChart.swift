import Charts
import SwiftUI

/// One zone's line on the erg detail screen (SPEC §13.8): in the accent colour, joined by
/// straight segments, with a point on the selected duration only. Its height is the
/// screen's to give: `detailChart()` lets it give way from 210 to 110 pt (§15.4).
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
                .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Color.accentColor)
            }

            if let selected = points.first(where: { $0.duration == selectedDuration }) {
                PointMark(
                    x: .value("Duration", selected.duration),
                    y: .value("Intensity", plotted(selected.intensity))
                )
                .symbolSize(90)
                .foregroundStyle(Color.accentColor)
            }

            RuleMark(x: .value("Duration", selectedDuration))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.grey.opacity(0.4))
                .zIndex(-1)
        }
        // **Linear and fixed at 0–20:00 on every erg and zone**, so lines compare and
        // switching zones never rescales the chart under your thumb. The inset keeps
        // `0:00`, centred under its tick, clear of the leading edge the chart bleeds off.
        .chartXScale(
            domain: 0...ZoneLine.axisEnd,
            range: .plotDimension(startPadding: 20, endPadding: 16)
        )
        .chartYScale(domain: yDomain)
        .chartXAxis {
            // The axis's labels only: no grid and no y axis, as §5.2's curve has none.
            AxisMarks(preset: .aligned, values: [0, 300, 600, 900, 1200]) { value in
                AxisValueLabel {
                    if let seconds = value.as(Int.self) {
                        Text(EnduranceText.clock(seconds))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            // Capped as the curve's are (SPEC §15.4).
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXSelection(value: Binding<Int?>(get: { selectedDuration }, set: { onSelect($0) }))
        .accessibilityLabel("Zone line")
    }

    /// **A split is plotted upside down**, so harder is up on every erg.
    private func plotted(_ intensity: Double) -> Double {
        intensity * unit.hardnessSign
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
