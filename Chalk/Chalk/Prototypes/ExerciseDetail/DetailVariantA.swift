// PROTOTYPE — throwaway. Variant A — Curve-first.
//
// The argument: the shape of your strength is the screen. One big chart, nothing
// competing with it. Exact numbers are not displayed at all until you touch the
// curve — a drag scrubs it and the readout follows your thumb.
// Cost: reading "what do I load for 5?" is a deliberate act, not a glance.

import Charts
import SwiftUI

struct DetailVariantACurveFirst: View {
    @Bindable var store: ProtoStore
    let onLog: () -> Void

    @State private var scrubbedReps: Int?
    @State private var historyReps: Int?

    private var readoutReps: Int { scrubbedReps ?? 5 }

    var body: some View {
        VStack(spacing: 0) {
            readout
            chart
            Spacer(minLength: 0)
            logBar
        }
        .navigationTitle(store.exerciseName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if store.isGymBound { ToolbarItem(placement: .topBarTrailing) { machineMenu } }
        }
        .sheet(item: Binding(get: { historyReps.map(RepsBox.init) },
                             set: { historyReps = $0?.reps })) { box in
            HistorySheet(store: store, reps: box.reps)
        }
    }

    // The only numbers on the screen, driven by where your thumb is.
    private var readout: some View {
        VStack(spacing: 4) {
            if let weight = store.best(at: readoutReps) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(weight.kg)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("kg").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                }
                Button {
                    historyReps = readoutReps
                } label: {
                    HStack(spacing: 4) {
                        Text("best for \(readoutReps) reps")
                        if store.isInherited(at: readoutReps) {
                            Image(systemName: "arrow.turn.up.left").font(.caption2)
                        }
                        Text("· \(store.history(atLeast: readoutReps).count) record\(store.history(atLeast: readoutReps).count == 1 ? "" : "s")")
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("—").font(.system(size: 56, weight: .bold, design: .rounded))
                Text("nothing logged yet").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .animation(.snappy, value: readoutReps)
        .padding(.top, 8)
    }

    private var chart: some View {
        Chart {
            ForEach(store.ghostCurve, id: \.reps) { point in
                LineMark(x: .value("Reps", point.reps), y: .value("kg", point.weight),
                         series: .value("Series", "ghost"))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
            ForEach(store.curve, id: \.reps) { point in
                LineMark(x: .value("Reps", point.reps), y: .value("kg", point.weight),
                         series: .value("Series", "best"))
                    .foregroundStyle(.tint)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                PointMark(x: .value("Reps", point.reps), y: .value("kg", point.weight))
                    .foregroundStyle(.tint)
                    .symbolSize(point.reps == readoutReps ? 160 : 40)
            }
            if store.best(at: readoutReps) != nil {
                RuleMark(x: .value("Reps", readoutReps))
                    .foregroundStyle(.tint.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXScale(domain: 0.6...12.4)
        .chartXAxis { AxisMarks(values: Array(1...12)) { AxisValueLabel() } }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geo[plotFrame].origin.x
                                if let raw: Double = proxy.value(atX: x) {
                                    scrubbedReps = min(12, max(1, Int(raw.rounded())))
                                }
                            }
                    )
                    .onTapGesture { historyReps = readoutReps }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var machineMenu: some View {
        Menu {
            Picker("Machine", selection: $store.currentMachineID) {
                ForEach(store.machines) { machine in
                    Text(machine.short).tag(Optional(machine.id))
                }
            }
        } label: {
            Label(store.currentMachine?.label ?? "Machine", systemImage: "chevron.down")
                .labelStyle(.titleAndIcon)
                .font(.footnote.weight(.semibold))
        }
    }

    private var logBar: some View {
        Button(action: onLog) {
            Label("Log", systemImage: "plus")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom, 76)
    }
}

/// Identifiable wrapper so an Int can drive `.sheet(item:)`.
struct RepsBox: Identifiable {
    let reps: Int
    var id: Int { reps }
}
