// PROTOTYPE — throwaway.
// The one piece all three variants share: the list behind a tapped rep count.
// Per https://github.com/hermanno3005/Chalk/issues/3, tapping n lists every record
// with reps >= n, because those are exactly the records that can set best[n].

import SwiftUI

struct HistorySheet: View {
    let store: ProtoStore
    let reps: Int

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.history(atLeast: reps)) { record in
                        HStack {
                            Text("\(record.reps) × \(record.weight.kg) kg")
                                .font(.body.monospacedDigit())
                                .fontWeight(record.id == store.sourceOfBest(at: reps)?.id ? .bold : .regular)
                            if record.id == store.sourceOfBest(at: reps)?.id {
                                Text("best").font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.tint.opacity(0.15), in: Capsule())
                            }
                            Spacer()
                            Text(record.date.proShort).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Every record at \(reps) reps or more")
                } footer: {
                    Text("Higher rep counts count toward \(reps)-rep best — a heavier set for more reps is strictly better.")
                }
            }
            .navigationTitle("\(reps)-rep history")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
