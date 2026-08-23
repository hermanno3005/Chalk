// PROTOTYPE — throwaway. Curve-first — the round-one winner, now under refinement.
//
// The argument: the shape of your strength is the screen. Exact numbers are not
// displayed until you touch the curve — dragging scrubs it and the readout follows
// your thumb. Round two varies only the curve's height (the dev found round one's
// full-bleed chart too big) and adds the navigation chrome that was missing.
//
// Scrubbing now uses Charts' own `chartXSelection` rather than a hand-rolled drag
// gesture — the round-one gesture fought with the tap gesture layered on top of it
// and often did nothing.

import Charts
import SwiftUI

struct DetailVariantACurveFirst: View {
    @Bindable var store: ProtoStore
    let size: CurveSize
    let onLog: () -> Void

    @State private var scrubbedReps: Int?
    @State private var historyReps: Int?

    private var readoutReps: Int { scrubbedReps ?? 5 }

    var body: some View {
        VStack(spacing: 0) {
            readout
            chart
            Spacer(minLength: 0)
            if size != .half { hole }
            Spacer(minLength: 0)
            logBar
        }
        .navigationTitle(store.exerciseName)
        .navigationBarTitleDisplayMode(size == .half ? .inline : .large)
        .toolbar {
            // Dead chrome — placement only. Real navigation belongs to
            // https://github.com/hermanno3005/Chalk/issues/8
            ToolbarItem(placement: .topBarLeading) {
                Button {} label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left").font(.body.weight(.semibold))
                        Text("Exercises")
                    }
                }
            }
            if store.isGymBound { ToolbarItem(placement: .topBarTrailing) { machineMenu } }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename exercise") {}
                    Button("Edit records") {}
                    Button("Delete exercise", role: .destructive) {}
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: Binding(get: { historyReps.map(RepsBox.init) },
                             set: { historyReps = $0?.reps })) { box in
            HistorySheet(store: store, reps: box.reps)
        }
    }

    /// Shrinking the curve leaves a hole. Marked, not filled — what goes here is the
    /// open question this round hands back.
    private var hole: some View {
        VStack(spacing: 4) {
            Text("empty").font(.footnote.weight(.semibold))
            Text("what fills the space the smaller curve freed up?").font(.caption2)
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            .foregroundStyle(.quaternary))
        .padding(.horizontal)
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
                    .lineStyle(StrokeStyle(lineWidth: size == .sparkline ? 2.5 : 3, lineCap: .round))
                PointMark(x: .value("Reps", point.reps), y: .value("kg", point.weight))
                    .foregroundStyle(.tint)
                    .symbolSize(point.reps == readoutReps ? (size == .sparkline ? 90 : 160) : (size == .sparkline ? 22 : 40))
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
        .chartYAxis {
            if size != .sparkline { AxisMarks(position: .leading) }
        }
        .chartXSelection(value: $scrubbedReps)
        .frame(height: size.height)
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
