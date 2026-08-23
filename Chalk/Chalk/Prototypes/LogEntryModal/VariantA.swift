// PROTOTYPE — throwaway.
//
// VARIANT A — Staged steppers. WINNER (https://github.com/hermanno3005/Chalk/issues/6).
// Reps first, then weight, one number on screen at a time at maximum size. Seeded
// from your most recent entry for this exercise. Feedback arrives only on the weight
// stage, once it can mean something. Tapping the big number opens a keypad, so a
// large jump does not cost a run of stepper taps.

import SwiftUI

struct VariantAStagedSteppers: View {
    @Bindable var store: ProtoStore
    let onSaved: (ProtoRecord) -> Void

    @State private var reps: Int
    @State private var weight: Double
    @State private var stage = Stage.reps
    // Screenshot hook: `-autoKeypad 1` opens with the keypad showing.
    @State private var typing: String? = UserDefaults.standard.bool(forKey: "autoKeypad") ? "12" : nil

    enum Stage { case reps, weight }

    init(store: ProtoStore, onSaved: @escaping (ProtoRecord) -> Void) {
        self.store = store
        self.onSaved = onSaved
        _reps = State(initialValue: store.mostRecent?.reps ?? 5)
        _weight = State(initialValue: store.mostRecent?.weight ?? 20)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 8)
            bigNumber
            Spacer(minLength: 8)
            verdictLine
            if typing == nil {
                stepperRow
            } else {
                keypad
            }
            primaryButton
        }
        .padding()
        .presentationDetents([.height(typing == nil ? 520 : 600)])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text(stage == .reps ? "How many reps?" : "What weight?")
                .font(.headline)
            Spacer()
            if stage == .weight {
                Button("\(reps) reps") { withAnimation { stage = .reps; typing = nil } }
                    .font(.subheadline)
            }
        }
        .padding(.top, 8)
    }

    /// Tappable: a tap swaps the steppers for a keypad, so 5 -> 12 reps or
    /// 20 -> 60 kg costs one tap plus the digits, not a run of nudges.
    private var bigNumber: some View {
        VStack(spacing: 4) {
            Text(displayValue)
                .font(.system(size: typing == nil ? 96 : 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(typing?.isEmpty == true ? .secondary : .primary)
            Text(stage == .reps ? "reps" : "kg")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(typing == nil ? Color.clear : Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 20))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { typing = typing == nil ? "" : nil } }
    }

    private var displayValue: String {
        if let typing {
            return typing.isEmpty ? "–" : typing
        }
        return stage == .reps ? "\(reps)" : weight.kg
    }

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]

    private var keypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(keys, id: \.self) { key in
                Button { press(key) } label: {
                    Text(key)
                        .font(.title.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .disabled(key == "." && stage == .reps)
            }
        }
        .padding(.vertical, 12)
    }

    private func press(_ key: String) {
        var text = typing ?? ""
        switch key {
        case "⌫": if !text.isEmpty { text.removeLast() }
        case ".": if !text.contains(".") { text.append(".") }
        default: text.append(key)
        }
        typing = text
        commitTyping()
    }

    /// The typed value flows straight into reps/weight so the verdict line stays live.
    private func commitTyping() {
        guard let typing, !typing.isEmpty else { return }
        if stage == .reps {
            reps = max(1, Int(typing) ?? reps)
        } else {
            weight = Double(typing) ?? weight
        }
    }

    @ViewBuilder
    private var verdictLine: some View {
        Group {
            if stage == .weight {
                switch store.verdict(reps: reps, weight: weight) {
                case .newBest(let by, _):
                    Label("Beats your \(reps)-rep best by \(by.kg) kg", systemImage: "arrow.up.right")
                        .foregroundStyle(.green)
                case .matchesBest:
                    Text("Matches your \(reps)-rep best").foregroundStyle(.secondary)
                case .below(let best):
                    Text("Your \(reps)-rep best is \(best.kg) kg").foregroundStyle(.secondary)
                case .firstEver:
                    Text("First entry at \(reps) reps").foregroundStyle(.secondary)
                case .invalid:
                    Text(" ")
                }
            } else {
                Text(" ")
            }
        }
        .font(.subheadline.weight(.medium))
        .frame(height: 24)
    }

    private var stepperRow: some View {
        HStack(spacing: 12) {
            stepButton("minus", enabled: stage == .reps ? reps > 1 : weight > step) { adjust(-1) }
            stepButton("plus", enabled: true) { adjust(1) }
        }
        .padding(.vertical, 16)
    }

    private var step: Double { stage == .reps ? 1 : 2.5 }

    private func adjust(_ direction: Int) {
        if stage == .reps {
            reps = max(1, reps + direction)
        } else {
            weight = max(2.5, weight + Double(direction) * 2.5)
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 88)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
    }

    private var primaryButton: some View {
        Button {
            if stage == .reps {
                withAnimation { stage = .weight; typing = nil }
            } else {
                store.save(reps: reps, weight: weight)
                onSaved(ProtoRecord(reps: reps, weight: weight, date: .now))
            }
        } label: {
            Text(stage == .reps ? "Next" : "Save")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
    }
}
