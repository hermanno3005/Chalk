import SwiftUI

// PROTOTYPE — round two. Round one picked B (the line under the readout) and
// grey-out for reached. This round varies only what that line carries — nothing
// else moves — and makes the Log bar live so the gap can be watched closing.

/// Round one's four are still in the tree as the primary source of that comparison;
/// the switcher now cycles these.
enum RoundTwoVariant: String, CaseIterable {
    case line = "R1"
    case donut = "R2"
    case bar = "R3"
    case delta = "R4"

    var name: String {
        switch self {
        case .line: "Line only"
        case .donut: "Donut"
        case .bar: "Hairline bar"
        case .delta: "The number moves"
        }
    }
}

/// Where a proportional glyph starts counting from. This is the honest-origin problem
/// round one found in variant C, made switchable rather than assumed away: a pie or a
/// bar has to answer it, and a plain line does not.
enum GoalOrigin: String, CaseIterable {
    /// `best / goal`. Cheap, needs nothing stored — and dishonest: you were never at
    /// zero, so every glyph starts mostly full.
    case zero = "from 0"
    /// `(best − best-when-set) / (goal − best-when-set)`. Honest, and it costs a second
    /// stored number: what your curve read when you named the goal.
    case whenSet = "from set"
}

/// The goal line, round two. Every variant is this row with a different thing in front
/// of the words — the words themselves, the grey-out and the placement never change.
struct GoalRow: View {
    let variant: RoundTwoVariant
    let goal: PrototypeGoal
    let gap: Double
    let fraction: Double
    let isReached: Bool
    /// What the last log took off the gap, for the one variant that says so out loud.
    let lastDelta: Double?

    var body: some View {
        HStack(spacing: 8) {
            switch variant {
            case .line:
                EmptyView()
            case .donut:
                Donut(fraction: fraction, tint: tint)
                    .frame(width: 18, height: 18)
            case .bar:
                EmptyView()
            case .delta:
                EmptyView()
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(tint)
                .contentTransition(.numericText())

            if variant == .delta, let lastDelta, !isReached {
                Text("−\(lastDelta.kilogramsText)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange, in: .capsule)
                    .transition(.scale.combined(with: .opacity))
            }

            if variant == .bar {
                Hairline(fraction: fraction, tint: tint)
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy(duration: 0.35), value: gap)
        .animation(.snappy(duration: 0.35), value: fraction)
    }

    private var tint: Color {
        isReached ? Color.secondary : .orange
    }

    private var text: String {
        let target = "Goal \(goal.weight.kilogramsText) × \(goal.reps)"
        return isReached ? "\(target) · reached" : "\(target) · \(gap.kilogramsText) kg to go"
    }
}

/// The pie, as asked for — a donut so it reads as a gauge rather than as a data chart,
/// at subhead height so it cannot outweigh the words beside it.
struct Donut: View {
    let fraction: Double
    let tint: Color
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// The thinnest possible bar: it takes the leftover width of the line's own row rather
/// than a block of its own, so the empty space below the curve stays empty.
struct Hairline: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.22))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(minWidth: 40)
    }
}
