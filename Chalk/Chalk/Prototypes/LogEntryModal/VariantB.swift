// PROTOTYPE — throwaway.
//
// VARIANT B — One-screen wheels. Both numbers visible and adjustable at once, no
// staging, no ordering question. Seeded with the current best at the last-used rep
// count, so the default is already "match your PR". Live verdict under the wheels.

import SwiftUI

struct VariantBWheels: View {
    @Bindable var store: ProtoStore
    let onSaved: (ProtoRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reps: Int
    @State private var weightIndex: Int

    /// 2.5 kg increments up to 300 kg.
    private static let weights: [Double] = stride(from: 2.5, through: 300, by: 2.5).map { $0 }

    private var weight: Double { Self.weights[weightIndex] }

    init(store: ProtoStore, onSaved: @escaping (ProtoRecord) -> Void) {
        self.store = store
        self.onSaved = onSaved
        let seedReps = store.mostRecent?.reps ?? 5
        let seedWeight = store.best(at: seedReps) ?? 20
        _reps = State(initialValue: seedReps)
        _weightIndex = State(initialValue: Self.weights.firstIndex(where: { $0 >= seedWeight }) ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text(store.exerciseName).font(.headline)
                Spacer()
                Text("Cancel").opacity(0) // balances the title
            }
            .padding()

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Text("reps").font(.caption).foregroundStyle(.secondary)
                    Picker("Reps", selection: $reps) {
                        ForEach(1...30, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                }
                VStack(spacing: 0) {
                    Text("kg").font(.caption).foregroundStyle(.secondary)
                    Picker("Weight", selection: $weightIndex) {
                        ForEach(Self.weights.indices, id: \.self) { Text(Self.weights[$0].kg).tag($0) }
                    }
                    .pickerStyle(.wheel)
                }
            }
            .frame(height: 236)

            verdict
                .frame(height: 44)

            Button {
                store.save(reps: reps, weight: weight)
                onSaved(ProtoRecord(reps: reps, weight: weight, date: .now))
            } label: {
                Text("Save")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var verdict: some View {
        switch store.verdict(reps: reps, weight: weight) {
        case .newBest(let by, let previous):
            VStack(spacing: 2) {
                Label("New \(reps)-rep best", systemImage: "trophy.fill").foregroundStyle(.green)
                Text("was \(previous.kg) kg — up \(by.kg)").font(.caption).foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
        case .matchesBest:
            Text("Matches your \(reps)-rep best of \(weight.kg) kg")
                .font(.subheadline).foregroundStyle(.secondary)
        case .below(let best):
            Text("\(reps)-rep best: \(best.kg) kg")
                .font(.subheadline).foregroundStyle(.secondary)
        case .firstEver:
            Text("First entry at \(reps) reps").font(.subheadline).foregroundStyle(.secondary)
        case .invalid:
            Text(" ")
        }
    }
}
