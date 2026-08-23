// PROTOTYPE — throwaway. Answers https://github.com/hermanno3005/Chalk/issues/7
//
// Three variants of the exercise detail screen, switchable from a floating bottom
// bar, over four sample datasets and both exercise kinds — so "what does the curve
// look like with four points, or with gaps?" and "where does the machine qualifier
// go?" are each one tap away.
//
// The Log button opens the *winning* log sheet from
// https://github.com/hermanno3005/Chalk/issues/6 (variant A, staged steppers), so
// the screen is judged with its real primary action attached.

import SwiftUI

/// Round two. Curve-first won, but the full-bleed chart was too big — so the switcher
/// now varies only the curve's height, everything else held constant.
/// Round one's table-first and answer-first screens stay in the tree as the primary
/// source of that comparison; they are no longer reachable from the switcher.
enum CurveSize: String, CaseIterable {
    case sparkline, compact, half

    var key: String { String(rawValue.prefix(1)).uppercased() }

    var name: String {
        switch self {
        case .sparkline: "Sparkline — 56pt"
        case .compact: "Compact — 150pt"
        case .half: "Half — 240pt"
        }
    }

    var height: CGFloat {
        switch self {
        case .sparkline: 56
        case .compact: 150
        case .half: 240
        }
    }
}

struct ExerciseDetailPrototypeRoot: View {
    @AppStorage("prototype.detail.variant") private var variantKey = CurveSize.compact.rawValue
    @AppStorage("prototype.detail.dataset") private var datasetKey = ProtoDataset.typical.rawValue
    @AppStorage("prototype.detail.gymBound") private var gymBound = false

    @State private var store = ProtoStore()
    // Screenshot hook: `-autoOpenLog 1` opens the log sheet on launch.
    @State private var isLogging = UserDefaults.standard.bool(forKey: "autoOpenLog")
    @State private var flash: ProtoRecord?

    private var variant: CurveSize { CurveSize(rawValue: variantKey) ?? .compact }
    private var dataset: ProtoDataset { ProtoDataset(rawValue: datasetKey) ?? .typical }

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                DetailVariantACurveFirst(store: store, size: variant, onLog: { isLogging = true })
                    .overlay(alignment: .top) { flashBanner }
            }
            switcher
        }
        .task { apply() }
        .sheet(isPresented: $isLogging) {
            VariantAStagedSteppers(store: store) { record in
                isLogging = false
                withAnimation { flash = record }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { flash = nil }
                }
            }
        }
    }

    private func apply() {
        store.exerciseName = gymBound ? "Chest Press" : "Bench Press"
        store.isGymBound = gymBound
        store.load(dataset)
    }

    @ViewBuilder
    private var flashBanner: some View {
        if let flash {
            Text("Logged \(flash.reps) × \(flash.weight.kg) kg")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.green.opacity(0.9), in: Capsule())
                .foregroundStyle(.white)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// High-contrast, deliberately not part of the design being judged.
    private var switcher: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                arrow("chevron.left", -1)
                VStack(spacing: 0) {
                    Text(variant.name).font(.footnote.weight(.semibold))
                    Text("prototype").font(.system(size: 9)).opacity(0.6)
                }
                .frame(width: 168)
                arrow("chevron.right", 1)
            }
            HStack(spacing: 8) {
                Button {
                    let all = ProtoDataset.allCases
                    let i = all.firstIndex(of: dataset) ?? 0
                    datasetKey = all[(i + 1) % all.count].rawValue
                    apply()
                } label: {
                    Text(dataset.name)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.16), in: Capsule())
                }
                Button {
                    gymBound.toggle()
                    apply()
                } label: {
                    Text(gymBound ? "gym-bound" : "free-weight")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.16), in: Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.black, in: RoundedRectangle(cornerRadius: 22))
        .foregroundStyle(.white)
        .shadow(radius: 8)
        .padding(.bottom, 8)
    }

    private func arrow(_ icon: String, _ offset: Int) -> some View {
        Button {
            let all = CurveSize.allCases
            let i = all.firstIndex(of: variant) ?? 0
            variantKey = all[(i + offset + all.count) % all.count].rawValue
        } label: {
            Image(systemName: icon).font(.body.weight(.bold))
                .frame(width: 38, height: 34).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExerciseDetailPrototypeRoot()
}
