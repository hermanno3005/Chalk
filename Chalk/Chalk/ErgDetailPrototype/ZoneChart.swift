import Charts
import SwiftUI

// PROTOTYPE — one chart for every variant (#98): zone lines over a duration axis. What
// varies between variants is how many lines it carries and what sits around it.

struct ProtoLine: Identifiable {
    let zone: Int
    let points: [ProtoPoint]
    let color: Color
    var id: Int { zone }
}

struct ZoneChart: View {
    let lines: [ProtoLine]
    let unit: ProtoUnit
    let axis: ProtoAxis
    let ghost: Bool
    let selectedSeconds: Int
    /// The durations a scrub can land on. Nothing between two points is a number you have
    /// held (ADR-0006), so the selection snaps.
    let selectable: [Int]
    let onSelect: (Int) -> Void
    var height: CGFloat = 150
    var endLabels = false

    var body: some View {
        Chart {
            if ghost {
                ForEach(lines) { line in
                    ForEach(ghostPoints(line), id: \.0) { seconds, value in
                        LineMark(
                            x: .value("Duration", Double(seconds)),
                            y: .value("Ghost", plot(value)),
                            series: .value("Series", "ghost-\(line.zone)")
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 5]))
                        .foregroundStyle(line.color.opacity(0.4))
                    }
                }
            }

            ForEach(lines) { line in
                ForEach(line.points) { point in
                    LineMark(
                        x: .value("Duration", Double(point.seconds)),
                        y: .value("Intensity", plot(point.value)),
                        series: .value("Series", "Z\(line.zone)")
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(line.color)

                    PointMark(
                        x: .value("Duration", Double(point.seconds)),
                        y: .value("Intensity", plot(point.value))
                    )
                    .symbolSize(point.seconds == selectedSeconds ? 90 : 26)
                    .foregroundStyle(line.color)
                    .annotation(position: .topTrailing, spacing: 2) {
                        if endLabels, point.seconds == line.points.last?.seconds {
                            Text("Z\(line.zone)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(line.color)
                        }
                    }
                }
            }

            RuleMark(x: .value("Duration", Double(selectedSeconds)))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.secondary.opacity(0.4))
                .zIndex(-1)
        }
        .chartXScale(
            domain: xDomain,
            range: .plotDimension(startPadding: 12, endPadding: 22),
            type: scaleType
        )
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: xMarks) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(ProtoFormat.duration(Int(seconds)))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(ProtoFormat.value(unit == .split ? -v : v, unit))
                    }
                }
            }
        }
        .chartXSelection(value: Binding<Double?>(
            get: { Double(selectedSeconds) },
            set: { raw in
                guard let raw, let snapped = snap(raw) else { return }
                onSelect(snapped)
            }
        ))
        .frame(height: height)
    }

    /// A split is lower when harder, so it is plotted negated: harder is up on every erg.
    private func plot(_ v: Double) -> Double { unit == .split ? -v : v }

    private func ghostPoints(_ line: ProtoLine) -> [(Int, Double)] {
        ProtoGhost.points(line.points, unit: unit, maxSeconds: Int(xDomain.upperBound))
    }

    private func snap(_ raw: Double) -> Int? {
        selectable.min { abs(log(Double($0)) - log(raw)) < abs(log(Double($1)) - log(raw)) }
    }

    private var done: [Int] { lines.flatMap { $0.points.map(\.seconds) } }

    private var scaleType: ScaleType {
        switch axis {
        case .fixedLinear, .framed: .linear
        case .fixedSqrt: .squareRoot
        case .fixedLog: .log
        }
    }

    private var xDomain: ClosedRange<Double> {
        switch axis {
        case .fixedLog: return 30...1200
        case .fixedLinear, .fixedSqrt: return 0...1200
        case .framed:
            let low = Double(done.min() ?? 60), high = Double(done.max() ?? 600)
            let end = ghost ? high * 1.5 : high
            let pad = max((end - low) * 0.08, 30)
            return max(0, low - pad)...(end + pad)
        }
    }

    private var xMarks: [Double] {
        switch axis {
        case .fixedLog: [30, 60, 120, 300, 600, 1200]
        case .fixedLinear, .fixedSqrt: [60, 300, 600, 900, 1200]
        case .framed: Set(done).sorted().map(Double.init)
        }
    }

    private var yDomain: ClosedRange<Double> {
        let ghostValues = ghost ? lines.flatMap { ghostPoints($0).map(\.1) } : []
        let values = (lines.flatMap { $0.points.map(\.value) } + ghostValues).map(plot)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let padding = max((high - low) * 0.15, max(abs(high) * 0.04, 1))
        return (low - padding)...(high + padding)
    }
}
