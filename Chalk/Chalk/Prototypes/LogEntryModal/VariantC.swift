// PROTOTYPE — throwaway.
//
// VARIANT C — Repeat-first. Starts from the premise that most logs repeat something
// you have already done, so generic entry is the fallback, not the main path.
// The top of the sheet is your recent combinations as one-tap chips: tap and it is
// logged, no confirm. "Something else" drops to a keypad for the genuinely new lift.

import SwiftUI

struct VariantCRepeatFirst: View {
    @Bindable var store: ProtoStore
    let onSaved: (ProtoRecord) -> Void

    // Screenshot hook: `-autoKeypad 1` opens straight onto the fallback path.
    @State private var showingKeypad = UserDefaults.standard.bool(forKey: "autoKeypad")
    @State private var repsText = UserDefaults.standard.bool(forKey: "autoKeypad") ? "6" : ""
    @State private var weightText = UserDefaults.standard.bool(forKey: "autoKeypad") ? "57.5" : ""
    @State private var editingWeight = UserDefaults.standard.bool(forKey: "autoKeypad")

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(showingKeypad ? "New entry" : "Log again")
                .font(.headline)
                .padding(.top, 12)

            if showingKeypad {
                keypadPath
            } else {
                chipsPath
            }
        }
        .padding()
        .presentationDetents([.height(showingKeypad ? 560 : 560)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Repeat chips

    private var chipsPath: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(store.recentCombos.prefix(5)) { combo in
                Button {
                    store.save(reps: combo.reps, weight: combo.weight)
                    onSaved(combo)
                } label: {
                    HStack {
                        Text("\(combo.reps) × \(combo.weight.kg) kg")
                            .font(.title2.weight(.semibold).monospacedDigit())
                        Spacer()
                        Text(combo.date, format: .relative(presentation: .numeric))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            Button("Something else…") {
                repsText = ""
                weightText = ""
                editingWeight = false
                showingKeypad = true
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 48)
        }
    }

    // MARK: - Keypad fallback

    private var reps: Int { Int(repsText) ?? 0 }
    private var weight: Double { Double(weightText) ?? 0 }

    private var keypadPath: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                field(value: repsText.isEmpty ? "–" : repsText, unit: "reps", active: !editingWeight)
                    .onTapGesture { editingWeight = false }
                field(value: weightText.isEmpty ? "–" : weightText, unit: "kg", active: editingWeight)
                    .onTapGesture { editingWeight = true }
            }

            keypad

            Button {
                store.save(reps: reps, weight: weight)
                onSaved(ProtoRecord(reps: reps, weight: weight, date: .now))
            } label: {
                Text("Save")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .disabled(reps < 1 || weight <= 0)
        }
    }

    private func field(value: String, unit: String, active: Bool) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(active ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(active ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(Rectangle())
    }

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]

    private var keypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(keys, id: \.self) { key in
                Button { press(key) } label: {
                    Text(key)
                        .font(.title.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func press(_ key: String) {
        var text = editingWeight ? weightText : repsText
        switch key {
        case "⌫": if !text.isEmpty { text.removeLast() }
        case ".": if editingWeight, !text.contains(".") { text.append(".") }
        default: text.append(key)
        }
        if editingWeight { weightText = text } else { repsText = text }

        // Reps are 1-2 digits: jump to weight as soon as a further tap is unlikely.
        if !editingWeight, repsText.count == 2 { editingWeight = true }
    }
}
