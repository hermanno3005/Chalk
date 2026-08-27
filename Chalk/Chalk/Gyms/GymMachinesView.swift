import SwiftUI

/// One gym's machines — the tap-through from `Manage gyms…` (SPEC §7.4), and the only
/// place `Move to another gym…` lives (SPEC §7.5).
struct GymMachinesView: View {
    let gym: Gym
    let gyms: GymsModel

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
    }

    private var machines: [Machine] {
        MachineScope.byRecency(gym.machines ?? [])
    }

    /// A machine, under the exercise it is one of — which is the way you read this list
    /// when something has gone wrong, because a split curve is two rows under one name.
    ///
    /// The verbs sit in a menu on the row. **When there is nowhere to move to, the menu
    /// is absent rather than disabled** — the rule §7.5 writes for `Merge into…`, which
    /// holds for the same reason here: a dead verb on a rare admin screen is a puzzle.
    @ViewBuilder
    private func row(_ machine: Machine) -> some View {
        let targets = gyms.moveTargets(excluding: gym)
        if targets.isEmpty {
            // The one gym you own has nowhere to move a machine to, so the row is a
            // plain label — not a greyed-out button, which reads as something broken.
            label(machine)
        } else {
            Menu {
                Menu("Move to another gym…", systemImage: "arrow.right") {
                    ForEach(targets, id: \.id) { target in
                        Button(target.name) { gyms.move(machine, to: target) }
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
