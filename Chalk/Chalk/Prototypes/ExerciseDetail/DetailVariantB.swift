// PROTOTYPE — throwaway. Variant B — Table-first.
//
// The argument: at the rack you read a number, you don't admire a picture. Rows
// 1–12, always all twelve, biggest type on the weight. The curve is demoted to a
// sparkline in the header that expands on tap — proving the two can coexist
// without the chart taking the screen.
// It also makes monotonic backfill *visible*: an inherited row is dimmed and says
// where its number came from.

import Charts
import SwiftUI

struct DetailVariantBTableFirst: View {
    @Bindable var store: ProtoStore
    let onLog: () -> Void

    // Screenshot hooks: `-expandCurve 1` opens the chart, `-autoOpenHistory 5` opens history.
    @State private var chartExpanded = UserDefaults.standard.bool(forKey: "expandCurve")
    @State private var historyReps: Int? = {
        let n = UserDefaults.standard.integer(forKey: "autoOpenHistory")
        return n > 0 ? n : nil
    }()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                Section {
                    sparklineHeader
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if store.isGymBound {
                    Section { machinePicker }
                }
                Section {
                    ForEach(1...12, id: \.self) { reps in row(reps) }
                } header: {
                    HStack {
                        Text("Reps")
                        Spacer()
                        Text("Best")
                    }
                } footer: {
                    Text("A dimmed row is carried down from a higher rep count — you have never logged that many reps directly.")
                }
            }
            .listStyle(.insetGrouped)
            logFab
        }
        .navigationTitle(store.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(get: { historyReps.map(RepsBox.init) },
                             set: { historyReps = $0?.reps })) { box in
            HistorySheet(store: store, reps: box.reps)
        }
    }

    private func row(_ reps: Int) -> some View {
        let weight = store.best(at: reps)
        let inherited = store.isInherited(at: reps)
        let source = store.sourceOfBest(at: reps)
        return Button {
            if weight != nil { historyReps = reps }
        } label: {
            HStack(spacing: 14) {
                Text("\(reps)")
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .frame(width: 34, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    if let weight {
                        Text("\(weight.kg) kg")
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(inherited ? .secondary : .primary)
                    } else {
                        Text("—").font(.title2.weight(.semibold)).foregroundStyle(.quaternary)
                    }
                    if let source {
                        Text(inherited ? "from \(source.reps) × \(source.weight.kg) · \(source.date.proAgo)"
                                       : source.date.proAgo)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if weight != nil {
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private var sparklineHeader: some View {
        Button {
            withAnimation(.snappy) { chartExpanded.toggle() }
        } label: {
            VStack(spacing: 6) {
                Chart {
                    ForEach(store.curve, id: \.reps) { point in
                        LineMark(x: .value("Reps", point.reps), y: .value("kg", point.weight),
                                 series: .value("Series", "best"))
                            .foregroundStyle(.tint)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    if chartExpanded {
                        ForEach(store.ghostCurve, id: \.reps) { point in
                            LineMark(x: .value("Reps", point.reps), y: .value("kg", point.weight),
                                     series: .value("Series", "ghost"))
                                .foregroundStyle(.secondary.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        }
                    }
                }
                .chartXScale(domain: 1...12)
                .chartXAxis(chartExpanded ? .visible : .hidden)
                .chartYAxis(chartExpanded ? .visible : .hidden)
                .frame(height: chartExpanded ? 190 : 44)
                HStack(spacing: 4) {
                    Text(chartExpanded ? "Hide curve" : "Curve")
                    Image(systemName: chartExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var machinePicker: some View {
        Picker("Machine", selection: $store.currentMachineID) {
            ForEach(store.machines) { machine in
                Text(machine.label).tag(Optional(machine.id))
            }
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
    }

    private var logFab: some View {
        Button(action: onLog) {
            Label("Log", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 22)
                .frame(height: 56)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(Capsule())
        .shadow(radius: 6, y: 3)
        .padding(.trailing, 20)
        .padding(.bottom, 80)
    }
}
