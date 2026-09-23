import SwiftUI

/// The goal sheet (#74): the log sheet's two-stage giant number, reps then weight,
/// naming a goal. **It commits with `Set goal`, never `Save`**, so it cannot be mistaken
/// for logging an entry.
///
/// Laid out as the log sheet is, minus its caption: the scope is always the one the
/// detail screen is showing. The line under the number is the goal's, in the goal colour
/// with no donut — nothing has been set yet, so there is no progress to draw.
struct GoalSheet: View {
    /// Held for the life of the presentation, as the log sheet holds its own.
    @State var model: GoalSheetModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                GiantNumber(number: $model.number)
                line
                Spacer(minLength: 0)
                TwoStageNumberInput(number: $model.number)
                clear
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .navigationTitle(model.hasGoal ? "Change goal" : "Set a goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    switch model.number.stage {
                    case .reps:
                        Button("Next") { withAnimation(.snappy) { model.number.advance() } }
                            .disabled(!model.number.canAdvance)
                    case .weight:
                        Button("Set goal") {
                            model.setGoal()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(!model.canSetGoal)
                    }
                }
            }
        }
    }

    /// The earlier answer, correctable without cancelling — the log sheet's header, with
    /// no date to state. Its row keeps its height on stage one so the number does not
    /// jump.
    private var header: some View {
        HStack {
            if model.number.stage == .weight {
                RepsBackButton(number: $model.number)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            Spacer(minLength: 0)
        }
        .frame(height: 44)
    }

    /// How far the number on screen is from your best. The space is reserved on both
    /// stages so the number above it does not shift.
    private var line: some View {
        Text(model.line?.text ?? " ")
            .font(.subheadline)
            .foregroundStyle(Color.goal(reached: model.line?.isReached == true))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 22)
            .animation(.snappy(duration: 0.2), value: model.line)
    }

    /// **At the foot of the sheet, and only where a goal exists.** No confirmation:
    /// naming one again is two stages away.
    @ViewBuilder
    private var clear: some View {
        if model.hasGoal {
            Button("Clear goal", role: .destructive) {
                model.clearGoal()
                dismiss()
            }
            .font(.subheadline)
            .padding(.top, 12)
        }
    }
}
