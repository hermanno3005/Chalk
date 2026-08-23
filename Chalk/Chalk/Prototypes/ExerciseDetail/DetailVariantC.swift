// PROTOTYPE — throwaway. Variant C — Answer-first.
//
// The argument: neither curve nor table is the primary thing — the *answer* is.
// You came to this screen holding a rep count in your head, so the screen opens on
// the last thing you did and a grid of chunky rep tiles you can hit with a thumb
// through a glove. The curve is behind a segmented control, so it never competes
// for space: it is a separate mode, not a companion.

import Charts
import SwiftUI

struct DetailVariantCAnswerFirst: View {
    @Bindable var store: ProtoStore
    let onLog: () -> Void

    @State private var mode = Mode.numbers
    @State private var historyReps: Int?
    @State private var showingMachines = false

    enum Mode: String, CaseIterable { case numbers = "Numbers", curve = "Curve" }

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 14) {
            hero
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch mode {
            case .numbers: tiles
            case .curve: curve
            }
            Spacer(minLength: 0)
            logBar
        }
        .navigationTitle(store.exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(get: { historyReps.map(RepsBox.init) },
                             set: { historyReps = $0?.reps })) { box in
            HistorySheet(store: store, reps: box.reps)
        }
        .confirmationDialog("Machine", isPresented: $showingMachines, titleVisibility: .visible) {
            ForEach(store.machines) { machine in
                Button(machine.short) { store.currentMachineID = machine.id }
            }
        }
    }

    // The lookup you actually came to make: what you did last, and what it takes to beat it.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let recent = store.mostRecent {
                Text("LAST TIME · \(recent.date.proAgo.uppercased())")
                    .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(recent.reps)").font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("×").font(.title2).foregroundStyle(.secondary)
                    Text(recent.weight.kg).font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("kg").font(.headline).foregroundStyle(.secondary)
                }
                if let best = store.best(at: recent.reps) {
                    Text(best > recent.weight
                         ? "Your \(recent.reps)-rep best is \(best.kg) kg"
                         : "That is your \(recent.reps)-rep best")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                Text("NOTHING LOGGED YET").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text("Tap Log to start").font(.title3.weight(.semibold))
            }
            if store.isGymBound {
                Button { showingMachines = true } label: {
                    Label(store.currentMachine?.short ?? "Pick a machine", systemImage: "arrow.left.arrow.right")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var tiles: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...12, id: \.self) { reps in tile(reps) }
            }
            .padding(.horizontal)
        }
    }

    private func tile(_ reps: Int) -> some View {
        let weight = store.best(at: reps)
        let inherited = store.isInherited(at: reps)
        return Button {
            if weight != nil { historyReps = reps }
        } label: {
            VStack(spacing: 2) {
                Text(reps == 1 ? "1 rep" : "\(reps) reps").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(weight?.kg ?? "—")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(weight == nil ? .tertiary : (inherited ? .secondary : .primary))
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var curve: some View {
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
            }
        }
        .chartXScale(domain: 1...12)
        .chartXAxis { AxisMarks(values: Array(1...12)) }
        .frame(height: 260)
        .padding(.horizontal)
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
