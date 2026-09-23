import SwiftUI

/// The goal's ring: **one view for every place that draws one**, at 18 pt, always
/// leading its words. It fills as the gap closes, from where you stood when the goal was
/// set, and **goes grey once reached** rather than vanishing or celebrating.
///
/// The goal colour is used by goal surfaces and nothing else, so an orange ring means a
/// goal wherever it appears.
struct GoalDonut: View {
    /// 0…1.
    let progress: Double
    let isReached: Bool

    static let size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: 4)
            Circle()
                // A sliver rather than nothing at zero would read as progress that is
                // not there, so an empty ring is drawn empty.
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: Self.size, height: Self.size)
        .animation(.snappy(duration: 0.35), value: progress)
        .accessibilityHidden(true)
    }

    private var tint: Color { .goal(reached: isReached) }
}

extension Color {
    /// The goal colour, or grey once reached — **a reached goal is always grey**, on every
    /// surface that draws one (SPEC §12.5).
    static func goal(reached: Bool) -> Color { reached ? .secondary : .goal }
}

/// The detail screen's goal line: `Goal 140 × 5 · 40 kg to go`, led by the donut, both
/// in the goal colour — and both grey once reached.
///
/// **No `›`**, unlike the readout's subhead above it: two stacked tappable rows are told
/// apart by the chevron, and this one opens a sheet about the goal, not a list.
struct GoalLineView: View {
    let line: ExerciseDetailModel.GoalLine

    var body: some View {
        HStack(spacing: 8) {
            GoalDonut(progress: line.progress, isReached: line.isReached)
            Text(line.text)
                .font(.subheadline)
                .contentTransition(.numericText())
        }
        .foregroundStyle(Color.goal(reached: line.isReached))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Changes the goal")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        GoalLineView(line: .init(text: "Goal 140 × 5 · 140 kg to go", isReached: false, progress: 0))
        GoalLineView(line: .init(text: "Goal 140 × 5 · 40 kg to go", isReached: false, progress: 0.33))
        GoalLineView(line: .init(text: "Goal 140 × 5 · reached", isReached: true, progress: 1))
    }
    .padding()
}
