// PROTOTYPE — throwaway.
//
// VARIANT A — Staged steppers. Reps first, then weight, one number on screen at a
// time at maximum size. Seeded from your most recent entry for this exercise.
// Feedback arrives only on the weight stage, once it can mean something.

import SwiftUI

struct VariantAStagedSteppers: View {
    @Bindable var store: ProtoStore
    let onSaved: (ProtoRecord) -> Void

    @State private var reps: Int
    @State private var weight: Double
    @State private var stage = Stage.reps

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
            Spacer()
            bigNumber
            Spacer()
            verdictLine
            stepperRow
            primaryButton
        }
        .padding()
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text(stage == .reps ? "How many reps?" : "What weight?")
                .font(.headline)
            Spacer()
            if stage == .weight {
                Button("\(reps) reps") { withAnimation { stage = .reps } }
                    .font(.subheadline)
            }
        }
        .padding(.top, 8)
    }

    private var bigNumber: some View {
        VStack(spacing: 4) {
            Text(stage == .reps ? "\(reps)" : weight.kg)
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(stage == .reps ? "reps" : "kg")
                .font(.title3)
                .foregroundStyle(.secondary)
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
                withAnimation { stage = .weight }
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
