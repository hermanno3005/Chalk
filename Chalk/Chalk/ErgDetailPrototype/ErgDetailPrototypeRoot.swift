import SwiftUI

// PROTOTYPE — the app root while this prototype is checked out (#98).
//
// Three erg detail screens, switchable from the black bar below the app, over the same
// zone lines. The pills cycle the erg (one per unit), the dataset (typical, a first visit
// that only reached Z5, a machine with nothing logged, zones not set), the duration axis,
// and whether a ghost is drawn past the longest duration.

struct ErgDetailPrototypeRoot: View {
    @AppStorage("prototype.variant") private var variant = DetailVariant.a.rawValue
    @AppStorage("prototype.erg") private var ergID = ProtoErg.treadmill.id
    @AppStorage("prototype.dataset") private var dataset = ProtoDataset.typical.rawValue
    @AppStorage("prototype.axis") private var axis = ProtoAxis.fixedLinear.rawValue
    @AppStorage("prototype.ghost") private var ghost = false
    private let startZone = UserDefaults.standard.integer(forKey: "prototype.zone")

    private var currentVariant: DetailVariant { DetailVariant(rawValue: variant) ?? .a }
    private var erg: ProtoErg { ProtoErg.all.first { $0.id == ergID } ?? .treadmill }
    private var currentDataset: ProtoDataset { ProtoDataset(rawValue: dataset) ?? .typical }
    private var currentAxis: ProtoAxis { ProtoAxis(rawValue: axis) ?? .fixedLog }

    var body: some View {
        VStack(spacing: 0) {
            ErgDetailHost(
                variant: currentVariant,
                dataset: currentDataset,
                ctx: ProtoContext(
                    erg: erg,
                    scope: erg.scope(currentDataset),
                    axis: currentAxis,
                    ghost: ghost,
                    startZone: startZone > 0 ? startZone : nil
                )
            )
            .id("\(variant)-\(ergID)-\(dataset)")
            switcher
        }
    }

    private var switcher: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button { cycleVariant(-1) } label: { Image(systemName: "chevron.left") }
                Text("\(currentVariant.rawValue) — \(currentVariant.name)")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 150)
                Button { cycleVariant(1) } label: { Image(systemName: "chevron.right") }
            }
            HStack(spacing: 6) {
                pill(erg.name) {
                    let all = ProtoErg.all
                    ergID = all[((all.firstIndex { $0.id == erg.id } ?? 0) + 1) % all.count].id
                }
                pill(currentDataset.rawValue) {
                    let all = ProtoDataset.allCases
                    dataset = all[(all.firstIndex(of: currentDataset)! + 1) % all.count].rawValue
                }
            }
            HStack(spacing: 6) {
                pill(currentAxis.rawValue) {
                    let all = ProtoAxis.allCases
                    axis = all[(all.firstIndex(of: currentAxis)! + 1) % all.count].rawValue
                }
                pill(ghost ? "ghost: past longest" : "ghost: none") { ghost.toggle() }
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func cycleVariant(_ step: Int) {
        let all = DetailVariant.allCases
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

/// The erg detail screen's frame — nav bar, machine qualifier, overflow, Log bar — the
/// same in every variant, so each is judged with its real chrome. **All of it is dead**:
/// placement only. The two states every variant shares (nothing logged, zones not set)
/// are drawn here once.
struct ErgDetailHost: View {
    let variant: DetailVariant
    let dataset: ProtoDataset
    let ctx: ProtoContext

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    switch dataset {
                    case .nothing: nothingLogged
                    case .noZones: zonesUnset
                    case .typical, .firstVisit:
                        switch variant {
                        case .a: OneZoneVariant(ctx: ctx)
                        case .b: EveryZoneVariant(ctx: ctx)
                        case .c: TableVariant(ctx: ctx)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(ctx.erg.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "chevron.left")
                }
                if let machine = ctx.erg.machineLabel(dataset) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Section("Urban Gym") { Button(ctx.erg.machine ?? "") {} }
                            if let fresh = ctx.erg.freshMachine {
                                Section("McFit") { Button(fresh) {} }
                            }
                        } label: {
                            Label(String(machine.split(separator: " · ").first ?? ""), systemImage: "square.stack.3d.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Rename", systemImage: "pencil") {}
                        Button("Change kind", systemImage: "arrow.left.arrow.right") {}
                        Button("Set a goal…", systemImage: "scope") {}
                        Button("Delete erg", systemImage: "trash", role: .destructive) {}
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {} label: {
                    Text("Log")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }

    /// §5.4, carried over: text where the chart would be, and the hint for a gym-bound
    /// erg whose sibling machine has history.
    private var nothingLogged: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing logged yet.")
                .font(.title3.weight(.medium))
            Text("Log an interval and your zone lines start here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let hint = ctx.erg.hint {
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 8)
    }

    /// Lines are gated until zones are set; logging is not (ADR-0005, ADR-0006).
    private var zonesUnset: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Set your heart-rate zones to read this \(ctx.erg.machine == nil ? "erg" : "machine").")
                .font(.title3.weight(.medium))
            Text("Your \(ctx.scope.entryCount) entries are kept. Zone lines appear once your zones are set.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Settings…") {}
                .font(.subheadline.weight(.medium))
                .padding(.top, 4)
        }
        .padding(.top, 8)
    }
}
