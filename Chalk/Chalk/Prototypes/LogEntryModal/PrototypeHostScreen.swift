// PROTOTYPE — throwaway. Rough exercise detail screen, present only so the modal
// is judged against real density rather than in a vacuum. Not a proposal for
// https://github.com/hermanno3005/Chalk/issues/7 — that ticket owns this screen.

import Charts
import SwiftUI

struct PrototypeHostScreen: View {
    @Bindable var store: ProtoStore
    let variant: LogVariant

    // Screenshot hook: `-autoOpenLog 1` opens the sheet on launch.
    @State private var isLogging = UserDefaults.standard.bool(forKey: "autoOpenLog")
    @State private var flash: ProtoRecord?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                curve
                Divider()
                repMaxRows
                Spacer(minLength: 0)
                logButton
            }
            .navigationTitle(store.exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .top) { flashBanner }
        }
        .sheet(isPresented: $isLogging) {
            switch variant {
            case .a: VariantAStagedSteppers(store: store, onSaved: saved)
            case .b: VariantBWheels(store: store, onSaved: saved)
            case .c: VariantCRepeatFirst(store: store, onSaved: saved)
            }
        }
    }

    private func saved(_ record: ProtoRecord) {
        isLogging = false
        withAnimation { flash = record }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { flash = nil }
        }
    }

    private var curve: some View {
        Chart {
            ForEach(store.ghostCurve, id: \.reps) { point in
                LineMark(x: .value("Reps", point.reps), y: .value("kg", point.weight))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
            }
            ForEach(store.curve, id: \.reps) { point in
                LineMark(x: .value("Reps", point.reps), y: .value("kg", point.weight))
                    .foregroundStyle(.tint)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                PointMark(x: .value("Reps", point.reps), y: .value("kg", point.weight))
                    .foregroundStyle(.tint)
            }
        }
        .chartXScale(domain: 1...12)
        .chartXAxis { AxisMarks(values: Array(1...12)) }
        .frame(height: 200)
        .padding()
    }

    private var repMaxRows: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(store.curve, id: \.reps) { point in
                    VStack(spacing: 2) {
                        Text("\(point.reps)").font(.caption2).foregroundStyle(.secondary)
                        Text(point.weight.kg).font(.headline.monospacedDigit())
                    }
                    .frame(width: 54, height: 52)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }

    private var logButton: some View {
        Button {
            isLogging = true
        } label: {
            Label("Log", systemImage: "plus")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom, 76) // clear of the prototype switcher
    }

    @ViewBuilder
    private var flashBanner: some View {
        if let flash {
            Text("Logged \(flash.reps) × \(flash.weight.kg) kg")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.green.opacity(0.9), in: Capsule())
                .foregroundStyle(.white)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
