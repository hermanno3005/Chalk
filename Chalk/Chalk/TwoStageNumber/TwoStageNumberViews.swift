import SwiftUI

// The two-stage number's controls (SPEC §6.1–6.2), drawn over a binding so any sheet can
// lay them out around its own header, caption and line. Each one is the input and
// nothing else: what the number means stays with the sheet that owns it.

/// The stage-two header's button: **the earlier answer, always visible and correctable
/// without cancelling** (SPEC §6.1).
struct RepsBackButton: View {
    @Binding var number: TwoStageNumber

    var body: some View {
        Button {
            withAnimation(.snappy) { number.backToReps() }
        } label: {
            Label(number.repsLabel, systemImage: "chevron.left")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }
}

/// The one thing on screen with weight. **Tapping it swaps the steppers for the keypad**
/// and back (SPEC §6.2); the digits move rather than cross-fading, which is what makes
/// staging read as progress rather than a detour (§6.1).
struct GiantNumber: View {
    @Binding var number: TwoStageNumber

    var body: some View {
        Button {
            withAnimation(.snappy) { number.tapNumber() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(number.numberText)
                    .font(.system(size: 92, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: number.numberText)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(number.unitText)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(number.numberText.isEmpty ? "Blank" : number.numberText) \(number.unitText)")
        .accessibilityHint(number.mode == .keypad ? "Shows the steppers" : "Types a number")
    }
}

/// Whichever input the number is in: the steppers, or the keypad.
struct TwoStageNumberInput: View {
    @Binding var number: TwoStageNumber

    var body: some View {
        switch number.mode {
        case .steppers: steppers
        case .keypad: NumberKeypad(decimalIsDead: number.stage == .reps) { number.type($0) }
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
            withAnimation(.snappy) { number.step(direction) }
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
        switch number.stage {
        case .reps: return up ? "One rep more" : "One rep fewer"
        case .weight: return up ? "Up to the next 2.5 kilograms" : "Down to the next 2.5 kilograms"
        }
    }
}
