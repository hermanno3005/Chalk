import SwiftUI

// PROTOTYPE — round three. The donut won; only **where it sits** is open. Nothing else
// varies: same words, same grey-out, same live Log bar, same origin switch.
enum DonutPlacement: String, CaseIterable {
    case inline = "P1"
    case row = "P2"
    case big = "P3"

    var name: String {
        switch self {
        case .inline: "Inline, small"
        case .row: "Row below the curve"
        case .big: "Big, number inside"
        }
    }
}

/// **P2** — the donut moves into the space §5.1 keeps empty, at 44 pt, with the words
/// beside it. No card, no fill, no border: the space stops being empty but does not
/// become a panel.
struct GoalRowBelow: View {
    let goal: PrototypeGoal
    let gap: Double
    let fraction: Double
    let isReached: Bool

    var body: some View {
        HStack(spacing: 14) {
            Donut(fraction: fraction, tint: tint)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(isReached ? "Reached" : "\(gap.kilogramsText) kg to go")
                    .font(.headline)
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Text("goal \(goal.weight.kilogramsText) kg × \(goal.reps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy(duration: 0.35), value: gap)
        .animation(.snappy(duration: 0.35), value: fraction)
    }

    private var tint: Color { isReached ? Color.secondary : .orange }
}

/// **P3** — the donut as the second thing on the screen, 120 pt, with the gap inside it.
/// The most motivating and the loudest: it is the only element that competes with the
/// scrub readout for being the number you look at.
struct GoalDialBelow: View {
    let goal: PrototypeGoal
    let gap: Double
    let fraction: Double
    let isReached: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Donut(fraction: fraction, tint: tint, lineWidth: 10)
                    .frame(width: 120, height: 120)
                VStack(spacing: 0) {
                    Text(isReached ? "—" : gap.kilogramsText)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(tint)
                    Text(isReached ? "reached" : "kg to go")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("goal \(goal.weight.kilogramsText) kg × \(goal.reps)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.35), value: gap)
        .animation(.snappy(duration: 0.35), value: fraction)
    }

    private var tint: Color { isReached ? Color.secondary : .orange }
}
