import SwiftUI

// PROTOTYPE — four structurally different answers to "How is a goal presented?".
// Each variant renders the whole screen body, so any of them is free to throw out the
// layout above the Log bar rather than decorating a shared one.

// MARK: - A — Curve marker

/// The goal lives **on the chart**: a dashed rule at the goal weight and a hollow point
/// at the rep count it was named for. Everything above and below the curve is untouched.
///
/// Its two costs are meant to be visible. The chart has to frame the goal, so a far one
/// squashes the staircase; and with no entries there is no chart at all, so the goal has
/// to fall back to a line of text — a second presentation to design and learn.
struct GoalVariantA: View {
    let model: GoalsPrototypeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.hasCurve {
                ScrubReadout(readout: readout(model))
                PrototypeCurve(
                    curve: model.curve,
                    selectedReps: model.selectedReps,
                    goal: model.goal,
                    isReached: model.isReached,
                    showGhost: model.showGhost,
                    onSelect: model.select
                )
            } else {
                PrototypeEmpty()
                if let goal = model.goal {
                    // The fallback the constraint forces. It is variant B's line,
                    // which is the point worth seeing.
                    GoalLine(goal: goal, gap: model.gap, isReached: model.isReached)
                }
            }
        }
    }
}

// MARK: - B — Gap under the readout

/// The goal is a **caption on the number you already came for**: one quiet line under
/// `best for N reps`, saying the target and what is left. The chart is untouched, the
/// empty space stays empty, and the zero-entry screen needs no second design because
/// the line was never a chart element.
struct GoalVariantB: View {
    let model: GoalsPrototypeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                if model.hasCurve {
                    ScrubReadout(readout: readout(model))
                } else {
                    PrototypeEmpty()
                }
                if let goal = model.goal {
                    GoalLine(goal: goal, gap: model.gap, isReached: model.isReached)
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
            }
        }
    }
}

// MARK: - C — A card in the empty space

/// The goal takes the space §5.1 leaves deliberately empty, and spends it on the app's
/// **one non-curve visual**: a progress bar from where you are to where you said you
/// were going. The most motivating of the four and the most expensive — it fills the
/// space that keeps the Log bar thumb-reachable.
struct GoalVariantC: View {
    let model: GoalsPrototypeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.hasCurve {
                ScrubReadout(readout: readout(model))
                PrototypeCurve(
                    curve: model.curve,
                    selectedReps: model.selectedReps,
                    goal: nil,
                    isReached: model.isReached,
                    showGhost: model.showGhost,
                    onSelect: model.select
                )
            } else {
                PrototypeEmpty()
            }
            if let goal = model.goal {
                GoalCard(
                    goal: goal,
                    best: model.curve.best[goal.reps],
                    gap: model.gap,
                    isReached: model.isReached
                )
            }
        }
    }
}

// MARK: - D — The gap is the headline

/// The **information hierarchy inverts**: the big number at the top stops being your
/// best and becomes what is left. `12.5 kg to go`, with your best and your goal shrunk
/// to the line beneath it.
///
/// It is the only variant where the motivation is the first thing you read, and the only
/// one that changes what the screen is about. A reached goal hands the headline back.
struct GoalVariantD: View {
    let model: GoalsPrototypeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let goal = model.goal, !model.isReached {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.gap.kilogramsText) kg to go")
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: model.gap)
                        .foregroundStyle(.orange)
                    Text(progressLine(model, goal))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if model.hasCurve {
                VStack(alignment: .leading, spacing: 6) {
                    ScrubReadout(readout: readout(model))
                    if let goal = model.goal, model.isReached {
                        GoalLine(goal: goal, gap: 0, isReached: true)
                    }
                }
            } else {
                PrototypeEmpty()
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
            }
        }
    }

    private func progressLine(_ model: GoalsPrototypeModel, _ goal: PrototypeGoal) -> String {
        guard let best = model.curve.best[goal.reps] else {
            return "goal \(goal.weight.kilogramsText) kg at \(goal.reps) reps · nothing logged"
        }
        return "\(best.kilogramsText) → \(goal.weight.kilogramsText) kg at \(goal.reps) reps"
    }
}

// MARK: - Shared pieces

/// Variant B's whole answer, and variant A's fallback when there is no chart to mark.
struct GoalLine: View {
    let goal: PrototypeGoal
    let gap: Double
    let isReached: Bool

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(isReached ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var text: String {
        let target = "Goal \(goal.weight.kilogramsText) × \(goal.reps)"
        return isReached ? "\(target) · reached" : "\(target) · \(gap.kilogramsText) kg to go"
    }
}

/// Variant C's card. The bar runs from nothing to the goal, not from your best — the
/// zero-entry case has to read as "all of it left" rather than as an error.
struct GoalCard: View {
    let goal: PrototypeGoal
    let best: Double?
    let gap: Double
    let isReached: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Goal · \(goal.weight.kilogramsText) kg × \(goal.reps)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(isReached ? "Reached" : "\(gap.kilogramsText) kg to go")
                    .font(.subheadline)
                    .foregroundStyle(isReached ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
            }
            ProgressView(value: fraction)
                .tint(isReached ? Color.secondary : .orange)
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
        .opacity(isReached ? 0.6 : 1)
    }

    private var fraction: Double {
        guard goal.weight > 0 else { return 0 }
        return min(1, (best ?? 0) / goal.weight)
    }
}

/// The shipping zero-entry state (SPEC §5.4), free-weight shape.
struct PrototypeEmpty: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing logged yet.")
                .font(.title3.weight(.medium))
            Text("Log a lift and your curve starts here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func readout(_ model: GoalsPrototypeModel) -> ExerciseDetailModel.Readout {
    ExerciseDetailModel.Readout(
        reps: model.selectedReps,
        weight: model.curve.best[model.selectedReps],
        entriesBehind: model.curve.entriesBehind[model.selectedReps] ?? 0
    )
}
