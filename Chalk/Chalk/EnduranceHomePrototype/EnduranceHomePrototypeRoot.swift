import SwiftUI

// PROTOTYPE — the app root while this prototype is checked out (#96).
//
// Four variants of the home screen's way from strength to endurance, switchable from
// the black bar at the bottom, over five datasets. The bar sits **below** the app rather
// than over it, so it never covers the search field or a tab bar — both of which are
// part of what is being judged.
struct EnduranceHomePrototypeRoot: View {
    @AppStorage("prototype.variant") private var variant = HomeVariant.a.rawValue
    @AppStorage("prototype.dataset") private var dataset = ProtoDataset.full.rawValue
    /// **Sticky.** The half on screen survives a relaunch in every variant that has one.
    @AppStorage("prototype.half") private var half = Half.strength.rawValue
    @State private var store: ProtoStore

    init() {
        let stored = UserDefaults.standard.string(forKey: "prototype.dataset")
        _store = State(initialValue: ProtoStore(dataset: ProtoDataset(rawValue: stored ?? "") ?? .full))
    }

    private var currentVariant: HomeVariant { HomeVariant(rawValue: variant) ?? .a }
    private var currentDataset: ProtoDataset { ProtoDataset(rawValue: dataset) ?? .full }
    private var halfBinding: Binding<Half> {
        Binding(get: { Half(rawValue: half) ?? .strength }, set: { half = $0.rawValue })
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch currentVariant {
                case .a: SegmentedHome(store: store, half: halfBinding)
                case .b: TabHome(store: store, half: halfBinding)
                case .c: TitleMenuHome(store: store, half: halfBinding)
                case .d: OneLibraryHome(store: store)
                }
            }
            .modelContainer(store.container)
            .id("\(variant)-\(dataset)")
            switcher
        }
        .onChange(of: dataset) { _, new in
            store = ProtoStore(dataset: ProtoDataset(rawValue: new) ?? .full)
        }
    }

    private var switcher: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button { cycleVariant(-1) } label: { Image(systemName: "chevron.left") }
                Text("\(currentVariant.rawValue) — \(currentVariant.name)")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 190)
                Button { cycleVariant(1) } label: { Image(systemName: "chevron.right") }
            }
            HStack(spacing: 8) {
                pill(currentDataset.rawValue) {
                    let all = ProtoDataset.allCases
                    dataset = all[(all.firstIndex(of: currentDataset)! + 1) % all.count].rawValue
                }
                pill("on: \(half)") {}
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func cycleVariant(_ step: Int) {
        let all = HomeVariant.allCases
        let index = all.firstIndex(of: currentVariant)!
        variant = all[(index + step + all.count) % all.count].rawValue
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.18), in: Capsule())
        }
    }
}
