import SwiftUI

/// The machine prompt behind `Change kind`, free-weight → gym-bound (SPEC §8).
///
/// **One decision: which machine the existing entries belong to.** A free-weight exercise
/// has no machines by construction — that is the whole reason the model refuses to keep
/// them across a flip — so there is nothing to pick between and this is not the app's one
/// machine picker (§5.3) drawn over an empty list. It asks for the gym and the machine's
/// optional name, in the same words `New machine here` asks them (§6.4), and the flip
/// happens the moment they are answered.
struct ChangeKindSheet: View {
    let change: KindChange
    let gyms: GymsModel
    /// The gym the entries move to, and the machine's name — `nil` where you skipped it.
    let onPick: (Gym, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    /// The gym whose row was tapped, held while the one-field alert is up. **Always
    /// asked** — you cannot know now whether a second machine is coming (SPEC §6.4).
    @State private var naming: Gym?
    @State private var creatingGym = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(change.promptDetail)
                        .foregroundStyle(.secondary)
                }
                Section(change.prompt) {
                    // Not archived and the current gym first: `gyms.gyms` is the same
                    // list the current-gym picker offers, and a gym you have stopped
                    // visiting is not where this exercise has been lifted (§7.4).
                    ForEach(gyms.gyms, id: \.id) { gym in
                        Button {
                            naming = gym
                        } label: {
                            Label(gym.name, systemImage: "building.2")
                        }
                    }
                    // The exercise may predate every gym you have — this is often the
                    // first moment one is needed at all.
                    Button("New gym…", systemImage: "plus") { creatingGym = true }
                }
            }
            .navigationTitle("Change kind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Literally the same one field, optional, with Skip, that the log sheet's
            // `New machine here` puts up (SPEC §6.4).
            .namingMachine(at: $naming, onName: pick)
            .sheet(isPresented: $creatingGym) {
                // The new gym joins the list behind this sheet and is tapped like any
                // other. It is not picked for you: raising the naming alert as the
                // gym sheet dismisses is the one presentation this screen cannot make
                // reliably, and a tap is cheaper than a prompt that sometimes fails.
                NewGymSheet(gyms: gyms, onCreate: { _ in })
            }
        }
        .presentationDetents([.medium])
    }

    private func pick(_ gym: Gym, named name: String?) {
        onPick(gym, name)
        dismiss()
    }
}
