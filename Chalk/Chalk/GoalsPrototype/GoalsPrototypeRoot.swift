import SwiftUI

// PROTOTYPE — the app root while this prototype is checked out.
//
// **Round two.** Round one picked B — the goal as a line under the scrub readout — and
// grey-out for a reached goal. The layout is therefore fixed now; the switcher varies
// only what that line carries, and the Log bar is live so the gap can be watched
// closing rather than just seen closed. Round one's four variants are still in the tree
// (`GoalVariants.swift`) as the primary source of that comparison, no longer reachable
// from the switcher.
struct GoalsPrototypeRoot: View {
    @State private var model = GoalsPrototypeModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    if model.hasCurve {
                        ScrubReadout(readout: readout)
                    } else {
                        PrototypeEmpty()
                    }
                    if let goal = model.goal {
                        GoalRow(
                            variant: model.roundTwo,
                            goal: goal,
                            gap: model.gap,
                            fraction: model.fraction,
                            isReached: model.isReached,
                            lastDelta: model.lastDelta
                        )
                    }
                }
                if model.hasCurve {
                    PrototypeCurve(
                        curve: model.curve,
                        selectedReps: model.selectedReps,
                        goal: nil,
                        isReached: model.isReached,
                        showGhost: model.showGhost,
                        onSelect: model.select
                    )
                    .animation(.snappy(duration: 0.35), value: model.logged.count)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle("Bench Press")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Rename", systemImage: "pencil") {}
                        Button("Change kind", systemImage: "arrow.left.arrow.right") {}
                        Button("Delete exercise", systemImage: "trash", role: .destructive) {}
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { logBar }
        }
        .overlay(alignment: .bottom) { switcher }
    }

    private var readout: ExerciseDetailModel.Readout {
        ExerciseDetailModel.Readout(
            reps: model.selectedReps,
            weight: model.curve.best[model.selectedReps],
            entriesBehind: model.curve.entriesBehind[model.selectedReps] ?? 0
        )
    }

    /// **Live.** Each tap logs 2.5 kg above where the curve stands, at the goal's rep
    /// count — the ordinary next session — so the gap, the glyph and the curve all move
    /// together and the presentation can be judged in motion.
    private var logBar: some View {
        Button {
            withAnimation(.snappy(duration: 0.35)) { model.logNext() }
        } label: {
            Text("Log")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom, 74)
    }

    private var switcher: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button {
                    model.roundTwo = GoalsPrototypeModel.cycle(model.roundTwo, -1)
                } label: { Image(systemName: "chevron.left") }
                Text("\(model.roundTwo.rawValue) — \(model.roundTwo.name)")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 190)
                Button {
                    model.roundTwo = GoalsPrototypeModel.cycle(model.roundTwo, 1)
                } label: { Image(systemName: "chevron.right") }
            }
            HStack(spacing: 8) {
                pill(model.dataset.rawValue) {
                    model.dataset = GoalsPrototypeModel.cycle(model.dataset, 1)
                    model.logged = []
                    model.lastDelta = nil
                }
                pill(model.goalState.rawValue) {
                    model.goalState = GoalsPrototypeModel.cycle(model.goalState, 1)
                    model.lastDelta = nil
                }
                pill(model.origin.rawValue) {
                    model.origin = GoalsPrototypeModel.cycle(model.origin, 1)
                }
                pill(model.showGhost ? "ghost on" : "ghost off") { model.showGhost.toggle() }
                pill("reset") {
                    model.logged = []
                    model.lastDelta = nil
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.85), in: .capsule)
        .padding(.bottom, 6)
    }

    private func pill(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.white.opacity(0.18), in: .capsule)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}
