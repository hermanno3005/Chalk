import SwiftUI

/// One gym's machines — the tap-through from `Manage gyms…` (SPEC §7.4), and the only
/// place `Move to another gym…` and `Merge into…` live (SPEC §7.5).
struct GymMachinesView: View {
    let gym: Gym
    let gyms: GymsModel

    /// The merge a tap has proposed, waiting on its confirmation — the pair itself
    /// rather than the two machines separately, because the direction is the thing
    /// people get wrong and the question is phrased from it.
    @State private var merging: MachineMerge?

    var body: some View {
        List {
            if machines.isEmpty {
                Text("No machines here yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(machines, id: \.id) { machine in
                row(machine)
            }
        }
        .navigationTitle(gym.name)
        .navigationBarTitleDisplayMode(.inline)
        // **The app's one destructive confirmation** (SPEC §7.5). It is here because the
        // merge is the only action irreversible *in principle*: once the entries are
        // re-pointed, nothing records that they were ever separate. Phrased as the
        // outcome, carrying the counts, and there is no undo behind it.
        //
        // `presenting:` hands the pair to the button rather than leaving it to read
        // `merging` back, which SwiftUI has already cleared by then.
        .confirmationDialog(
            Text(merging?.question ?? ""),
            isPresented: Binding(
                get: { merging != nil },
                set: { if !$0 { merging = nil } }
            ),
            titleVisibility: .visible,
            presenting: merging
        ) { merge in
            Button("Merge", role: .destructive) { gyms.merge(merge.loser, into: merge.winner) }
            Button("Cancel", role: .cancel) {}
        } message: { merge in
            Text(merge.detail)
        }
    }

    private var machines: [Machine] {
        MachineScope.byRecency(gym.machines ?? [])
    }

    /// A machine, under the exercise it is one of — which is the way you read this list
    /// when something has gone wrong, because a split curve is two rows under one name.
    ///
    /// The verbs sit in a menu on the row, and **each is absent rather than disabled
    /// where it has nowhere to go** — the rule §7.5 writes for `Merge into…`, which holds
    /// for the same reason for `Move to another gym…`: a dead verb on a rare admin screen
    /// is a puzzle. With neither, the row is a plain label and there is no menu at all.
    @ViewBuilder
    private func row(_ machine: Machine) -> some View {
        let moveTargets = gyms.moveTargets(excluding: gym)
        let mergeTargets = gyms.mergeTargets(for: machine)
        if moveTargets.isEmpty && mergeTargets.isEmpty {
            label(machine)
        } else {
            Menu {
                if !moveTargets.isEmpty {
                    Menu("Move to another gym…", systemImage: "arrow.right") {
                        ForEach(moveTargets, id: \.id) { target in
                            Button(target.name) { gyms.move(machine, to: target) }
                        }
                    }
                }
                // Only ever this machine's same-gym, same-exercise siblings: merging
                // across gyms is incoherent by construction.
                if !mergeTargets.isEmpty {
                    Menu("Merge into…", systemImage: "arrow.triangle.merge") {
                        ForEach(mergeTargets, id: \.id) { target in
                            Button(target.name) {
                                merging = MachineMerge(loser: machine, winner: target)
                            }
                        }
                    }
                }
            } label: {
                label(machine)
            }
            .foregroundStyle(.primary)
        }
    }

    /// A machine under the exercise it belongs to.
    private func label(_ machine: Machine) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(machine.exercise?.name ?? "No exercise")
            Text(machine.name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
