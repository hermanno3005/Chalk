import SwiftUI

/// One gym's machines — the tap-through from `Manage gyms…` (SPEC §7.4), and the only
/// place `Rename…`, `Move to another gym…` and `Merge into…` live (SPEC §7.5).
///
/// **Strength and Endurance sections** (§13.11), each most recently used first, an empty
/// one hidden — and never filtered by the half you came from: it is one screen.
///
/// On an erg's machine, `Rename…` and Move run the near-name check first
/// (`ErgModelMatch`): it warns and never blocks, so dismissing a question goes ahead with
/// what you asked for — except Move's, whose *Cancel* is one of its three answers.
struct GymMachinesView: View {
    let gym: Gym
    let gyms: GymsModel

    /// The merge a tap has proposed, waiting on its confirmation — the pair itself
    /// rather than the two machines separately, because the direction is the thing
    /// people get wrong and the question is phrased from it.
    @State private var merging: MachineMerge?

    /// The machine a `Rename…` alert is open over, and its draft.
    @State private var renaming: Machine?
    @State private var renamed = ""

    /// A near-name question waiting on its answer.
    @State private var asking: Question?

    /// What the erg near-name check asks before a rename or a move goes ahead.
    private enum Question {
        /// The typed name looks like this erg's machine — a sibling here (offer
        /// `Merge into…`) or one at another gym (offer its spelling).
        case rename(Machine, ErgModelMatch)
        /// The target gym already has a passing machine for this erg.
        case move(Machine, Gym, ErgModelMatch)

        var title: String {
            switch self {
            case .rename(_, let match): match.warning
            case .move(_, _, let match): match.moveQuestion
            }
        }
    }

    var body: some View {
        List {
            if list.sections.isEmpty {
                Text("No machines here yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(list.sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(list.machines(in: section), id: \.id) { machine in
                        row(machine)
                    }
                }
            }
        }
        .navigationTitle(gym.name)
        .navigationBarTitleDisplayMode(.inline)
        // `presenting:` hands the machine to the action rather than leaving it to read
        // `renaming` back, which SwiftUI has already cleared by then.
        .alert("Rename machine", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        ), presenting: renaming) { machine in
            TextField("Name", text: $renamed)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { rename(machine, to: renamed) }
        }
        .confirmationDialog(
            Text(asking?.title ?? ""),
            isPresented: Binding(
                get: { asking != nil },
                set: { if !$0 { asking = nil } }
            ),
            titleVisibility: .visible,
            presenting: asking
        ) { question in
            answers(to: question)
        }
        // **The app's one destructive confirmation** (SPEC §7.5). It is here because the
        // merge is the only action irreversible *in principle*: once the entries are
        // re-pointed, nothing records that they were ever separate. Phrased as the
        // outcome, carrying the counts, and there is no undo behind it.
        .confirmationDialog(
            Text(merging?.question ?? ""),
            isPresented: Binding(
                get: { merging != nil },
                set: { if !$0 { merging = nil } }
            ),
            titleVisibility: .visible,
            presenting: merging
        ) { merge in
            Button("Merge", role: .destructive) {
                // Move's *Merge into it?* pairs machines at two gyms; the machine moves
                // there and merges once the two are siblings.
                if merge.loser.gym?.id == merge.sibling.gym?.id {
                    gyms.merge(merge.loser, into: merge.sibling)
                } else {
                    gyms.move(merge.loser, mergingInto: merge.sibling)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { merge in
            Text(merge.detail)
        }
    }

    private var list: GymMachinesList {
        GymMachinesList(gym: gym)
    }

    /// Where a machine can move to — the same for every row on this screen, because it
    /// is a property of the gyms you own and not of the machine.
    private var moveTargets: [Gym] {
        gyms.moveTargets(excluding: gym)
    }

    /// A machine, under the exercise it is one of — which is the way you read this list
    /// when something has gone wrong, because a split curve is two rows under one name.
    ///
    /// The verbs sit in a menu on the row. `Rename…` is always there; Move and Merge are
    /// **absent rather than disabled where they have nowhere to go** — the rule §7.5
    /// writes for `Merge into…`: a dead verb on a rare admin screen is a puzzle.
    private func row(_ machine: Machine) -> some View {
        let mergeTargets = MachineMerge.targets(for: machine)
        return Menu {
            Button("Rename…", systemImage: "pencil") {
                renamed = machine.label ?? ""
                renaming = machine
            }
            if !moveTargets.isEmpty {
                Menu("Move to another gym…", systemImage: "arrow.right") {
                    ForEach(moveTargets, id: \.id) { target in
                        Button(target.name) { move(machine, to: target) }
                    }
                }
            }
            // Only ever this machine's same-gym, same-exercise siblings: merging
            // across gyms is incoherent by construction.
            if !mergeTargets.isEmpty {
                Menu("Merge into…", systemImage: "arrow.triangle.merge") {
                    ForEach(mergeTargets, id: \.id) { target in
                        Button(target.name) {
                            merging = MachineMerge(loser: machine, sibling: target)
                        }
                    }
                }
            }
        } label: {
            label(machine)
        }
        .foregroundStyle(.primary)
    }

    /// `Rename…`'s answer: on an erg machine whose new name looks like one of the erg's
    /// machines, asked about first; otherwise renamed. A blank name changes nothing.
    private func rename(_ machine: Machine, to name: String) {
        if let match = ErgModelMatch.onRename(machine, to: name) {
            asking = .rename(machine, match)
        } else {
            gyms.rename(machine, to: name)
        }
    }

    /// Move's answer: where the target already has a passing machine for this erg, asked
    /// about first; otherwise moved.
    private func move(_ machine: Machine, to target: Gym) {
        if let match = ErgModelMatch.onMove(machine, to: target) {
            asking = .move(machine, target, match)
        } else {
            gyms.move(machine, to: target)
        }
    }

    @ViewBuilder
    private func answers(to question: Question) -> some View {
        switch question {
        case .rename(let machine, let match):
            if let merge = match.merge(from: machine) {
                Button("Merge into \(match.spelling)") { merging = merge }
            } else {
                Button("Use \(match.spelling)") { gyms.rename(machine, to: match.spelling) }
            }
            // The cancel role, so dismissing it renames as typed: a warning, not a gate.
            Button("Keep “\(match.typed)”", role: .cancel) { gyms.rename(machine, to: match.typed) }
        case .move(let machine, let target, let match):
            if let merge = match.merge(from: machine) {
                Button("Merge") { merging = merge }
            }
            Button("Move anyway") { gyms.move(machine, to: target) }
            Button("Cancel", role: .cancel) {}
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
