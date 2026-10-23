import Charts
import SwiftUI

/// The strength curve and the ghost behind it (SPEC §5.2).
///
/// **Drawn only where there is something to draw.** The zero-entry screen shows text
/// instead — no axes, no flat line, no ghost (§5.4), so this view never has to render an
/// empty frame and never invents a domain to do it.
struct StrengthCurve: View {
    let curve: RepMaxCurve
    let selectedReps: Int
    /// `chartXSelection` writes `nil` here on lift; the model ignores that and keeps the
    /// last real value, which is what makes the selection sticky.
    let onSelect: (Int?) -> Void

    /// 150 pt. Full-bleed was tried and rejected: it makes the screen read as a chart
    /// rather than as an exercise (SPEC §5.1).
    static let height: CGFloat = 150

    /// PROTOTYPE (#140): whether round two's chart treatment applies.
    private static var tr: Bool { Palette.current.isTradeRepublic }

    var body: some View {
        Chart {
            // The ghost is drawn first so the solid curve sits over it, and
            // unconditionally: wherever a curve is drawn at all, its headroom is too.
            ForEach(ghost) { point in
                LineMark(
                    x: .value("Reps", point.reps),
                    y: .value("Ghost", point.weight),
                    series: .value("Series", "ghost")
                )
                .interpolationMethod(.monotone)
                // PROTOTYPE (#140): round two dots it, as Trade Republic dots its
                // reference line.
                .lineStyle(Self.tr ? StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 6]) : StrokeStyle(lineWidth: 2, dash: [4, 5]))
                // Grey and dashed against a solid tinted line, rather than a paler
                // shade of the same thing: the first scaffolding drew both as thin
                // dashed grey and failed both halves of the rule (SPEC §5.2).
                .foregroundStyle(Self.tr ? Palette.current.secondaryText ?? .secondary : Color.secondary.opacity(0.55))
            }

            // Stepped, with a point on every rep count: monotonic backfill repeats the
            // value above, so the honest picture is a staircase and not a slope.
            ForEach(best) { point in
                LineMark(
                    x: .value("Reps", point.reps),
                    y: .value("Rep-max", point.weight),
                    series: .value("Series", "best")
                )
                .interpolationMethod(.stepEnd)
                .lineStyle(StrokeStyle(lineWidth: Self.tr ? 3.5 : 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Palette.current.accent)

                PointMark(
                    x: .value("Reps", point.reps),
                    y: .value("Rep-max", point.weight)
                )
                // PROTOTYPE (#140): round two marks only the selected point.
                .symbolSize(point.reps == selectedReps ? 90 : Self.tr ? 0 : 22)
                .foregroundStyle(Palette.current.accent)
            }

            // Drawn wherever the scrub is, including over a rep count the curve has
            // not reached: the readout says that cell is unproven, and the rule is
            // what says which cell it is talking about.
            RuleMark(x: .value("Reps", selectedReps))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.secondary.opacity(0.4))
                // Behind the marks above it, so the thumb tracker never covers the
                // point it is tracking.
                .zIndex(-1)
        }
        // Identical on every exercise, so shapes are comparable between them. The
        // padding is plot inset, not domain: it keeps the marks at 1 and 12 — and their
        // axis labels — off the edges without moving any point relative to another.
        .chartXScale(
            domain: RepMaxCurve.repRange,
            range: .plotDimension(startPadding: 10, endPadding: 10)
        )
        // Framed to the data, never anchored at 0: real strength curves are shallow and
        // a zero-based axis flattens them into the top third.
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: [1, 3, 5, 8, 12]) { value in
                // PROTOTYPE (#140): round two draws no grid.
                if !Self.tr { AxisGridLine() }
                AxisValueLabel {
                    if let reps = value.as(Int.self) {
                        Text("\(reps)")
                            .font(Self.tr ? .system(size: 13, weight: .semibold) : nil)
                            .foregroundStyle(Self.tr && reps == selectedReps ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                if !Self.tr { AxisGridLine() }
                AxisValueLabel()
                    .font(Self.tr ? .system(size: 12, weight: .semibold) : .caption2)
            }
        }
        // PROTOTYPE (#140): E draws no y axis at all.
        .chartYAxis(Palette.current.style == .layout ? .hidden : .automatic)
        // Charts' own selection. A `DragGesture` in a `chartOverlay` with a tap gesture
        // over it is the failure this replaces: the two fight and the drag does nothing.
        .chartXSelection(value: Binding<Int?>(get: { selectedReps }, set: { onSelect($0) }))
        // PROTOTYPE (#140): E's chart is the one thing on the screen that gives way. It
        // takes up to 210 pt and shrinks to 110 before anything is pushed off: the
        // screen never scrolls, and the Log bar is always on it.
        .frame(
            minHeight: Palette.current.style == .layout ? 110 : Self.height,
            maxHeight: Palette.current.style == .layout ? 210 : Self.height
        )
        .accessibilityLabel("Strength curve")
    }

    private var best: [CurvePoint] { Self.points(curve.best) }

    private var ghost: [CurvePoint] { Self.points(curve.ghost) }

    private static func points(_ weights: [Int: Double]) -> [CurvePoint] {
        RepMaxCurve.repRange.compactMap { reps in
            weights[reps].map { CurvePoint(reps: reps, weight: $0) }
        }
    }

    /// Framed to what is drawn — both curves — with a little air, and **never anchored
    /// at 0**: real strength curves are shallow and a zero-based axis flattens them into
    /// the top third (SPEC §5.2).
    ///
    /// The ghost counts as drawn data here. Framing to the staircase alone reads as the
    /// stricter answer and is not: wherever the staircase has real shape the ghost falls
    /// inside its range anyway and changes nothing, and where it does not — one entry,
    /// a flat curve — the Epley line is steep enough to leave the plot entirely, which
    /// is the one thing §5.2 says the ghost may never do.
    private var yDomain: ClosedRange<Double> {
        let weights = best.map(\.weight) + ghost.map(\.weight)
        guard let low = weights.min(), let high = weights.max() else { return 0...1 }
        // A single entry can put every point on one weight; a zero-width domain draws
        // nothing at all, so it gets an arbitrary band around itself.
        let padding = max((high - low) * 0.12, max(high * 0.05, 1))
        return (low - padding)...(high + padding)
    }

    private struct CurvePoint: Identifiable {
        let reps: Int
        let weight: Double
        var id: Int { reps }
    }
}

#Preview("A curve with shape") {
    StrengthCurve(
        curve: RepMaxCurve(entries: [
            Entry(reps: 1, weight: 120), Entry(reps: 3, weight: 110),
            Entry(reps: 5, weight: 100), Entry(reps: 8, weight: 85),
        ]),
        selectedReps: 5,
        onSelect: { _ in }
    )
    .padding()
}

/// The case the ghost has to survive: one entry, a flat curve, and a projection that
/// still has to read as guidance rather than as a record (SPEC §5.2).
#Preview("A single entry") {
    StrengthCurve(
        curve: RepMaxCurve(entries: [Entry(reps: 5, weight: 55)]),
        selectedReps: 5,
        onSelect: { _ in }
    )
    .padding()
}
