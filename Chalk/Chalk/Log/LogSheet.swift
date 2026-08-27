import SwiftUI

/// The log sheet (SPEC §6.1–6.3, §6.5, §6.7): reps, then weight, **one giant number on
/// screen at a time**. The size and the staging are the point — a single unmissable
/// digit and two thumb-sized targets is what survives sweaty hands.
///
/// **The same sheet is the edit sheet** (SPEC §6.6): opened from a history row it seeds
/// from that entry and writes back in place, differing only in the date it states and
/// will not let you change.
///
/// Free-weight only. The machine caption (§6.4) is a line above the number and a fifth
/// verdict state below it, and lands with machine resolution (#28, #29).
struct LogSheet: View {
    /// Held in `@State` for the life of the presentation, as the detail screen holds
    /// its own model: the sheet's content is rebuilt as the screen behind it changes,
    /// and every model past the first is dropped. Dismissing tears it down, so the next
    /// presentation seeds afresh from your most recent entry.
    @State var model: LogSheetModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                number
                verdict
                Spacer(minLength: 0)
                input
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .navigationTitle(model.exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Dismisses without writing (SPEC §6.1).
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    switch model.stage {
                    case .reps:
                        Button("Next") { withAnimation(.snappy) { model.advance() } }
                            .disabled(!model.canAdvance)
                    case .weight:
                        Button("Save") {
                            model.save()
                            // Never stays open to log again: sessions are not modelled
                            // (SPEC §6.7).
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(!model.canSave)
                    }
                }
            }
        }
    }

    /// The stage-two header: **the earlier answer, always visible and correctable
    /// without cancelling** (SPEC §6.1). Its row keeps its height on stage one so the
    /// number does not jump as the stages change.
    private var header: some View {
        HStack {
            if model.stage == .weight {
                Button {
                    withAnimation(.snappy) { model.backToReps() }
                } label: {
                    Label(model.repsLabel, systemImage: "chevron.left")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            Spacer(minLength: 0)
            // An edit says which lift it is correcting. The date is not editable
            // (SPEC §6.6), so it is stated rather than offered.
            if let dateLabel = model.dateLabel {
                Text(dateLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 44)
    }

    /// The one thing on screen with weight. **Tapping it swaps the steppers for the
    /// keypad** and back (SPEC §6.2); the digits move rather than cross-fading, which
    /// is what makes staging read as progress rather than a detour (§6.1).
    private var number: some View {
        Button {
            withAnimation(.snappy) { model.tapNumber() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.numberText)
                    .font(.system(size: 92, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: model.numberText)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(model.unitText)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.numberText.isEmpty ? "Blank" : model.numberText) \(model.unitText)")
        .accessibilityHint(model.mode == .keypad ? "Shows the steppers" : "Types a number")
    }

    /// **Weight stage only** (SPEC §6.5). The space is reserved on both stages: a line
    /// that comes and goes shifts the number above it.
    private var verdict: some View {
        Text(model.verdict ?? " ")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 22)
            .animation(.snappy(duration: 0.2), value: model.verdict)
    }

    @ViewBuilder
    private var input: some View {
        switch model.mode {
        case .steppers: steppers
        case .keypad: LogKeypad(decimalIsDead: model.stage == .reps, onKey: model.type)
        }
    }

    /// **±1 rep, ±2.5 kg**, and on weight the step snaps to the grid rather than adding
    /// (SPEC §6.2). Tap only — no hold-to-repeat and no acceleration, so these are plain
    /// buttons and nothing here recognises a long press.
    private var steppers: some View {
        HStack(spacing: 16) {
            stepper(-1, symbol: "minus")
            stepper(+1, symbol: "plus")
        }
    }

    private func stepper(_ direction: Int, symbol: String) -> some View {
        Button {
            withAnimation(.snappy) { model.step(direction) }
        } label: {
            Image(systemName: symbol)
                .font(.title.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 88)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .accessibilityLabel(stepperLabel(direction))
    }

    private func stepperLabel(_ direction: Int) -> String {
        let up = direction > 0
        switch model.stage {
        case .reps: return up ? "One rep more" : "One rep fewer"
        case .weight: return up ? "Up to the next 2.5 kilograms" : "Down to the next 2.5 kilograms"
        }
    }
}
