import SwiftUI

/// **`Manage gyms…`** — the one gym admin surface (SPEC §7.4), at the foot of the
/// library overflow's Gym menu and a direct sibling of *Edit groups*, symmetric on
/// purpose.
///
/// **Log-time menus stay pure pickers — they resolve, they never administer.** Nothing
/// destructive belongs one slip away from the two-tap log path, which is why every verb
/// here is here and not on the machine picker.
///
/// Gyms in recency order: **tap** to rename, **swipe** to archive, **full-swipe** to
/// delete a gym with no machines, archived ones in a section at the bottom, and a **tap
/// through** to the gym's machines.
struct ManageGymsSheet: View {
    let gyms: GymsModel

    @Environment(\.dismiss) private var dismiss

    /// The gym a tap opened the rename alert over — the gym itself rather than its name,
    /// because two gyms may share one and renaming the wrong one is exactly the quiet
    /// mistake this screen must not make.
    @State private var renaming: Gym?
    @State private var renamed = ""

    var body: some View {
        NavigationStack {
            List {
                if list.isEmpty {
                    Section {
                        Text("No gyms yet. One is created the first time you log on a machine, or from New gym… in the same menu you opened this from.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(list.inUse, id: \.id, content: row)
                    } header: {
                        Text("Gyms")
                    } footer: {
                        Text("Tap to rename — a gym is remembered by identity, so renaming one costs its history nothing. Swipe to archive: an archived gym keeps every entry it holds and comes back the moment you log there again.")
                    }
                }

                // One section at the bottom, however many gyms it holds. There is no
                // *restore* verb to put on these rows (SPEC §7.4).
                if !list.archived.isEmpty {
                    Section("Archived") {
                        ForEach(list.archived, id: \.id, content: row)
                    }
                }
            }
            .navigationTitle("Gyms")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Gym.self) { gym in
                GymMachinesView(gym: gym, gyms: gyms)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // `presenting:` hands the gym to the action rather than leaving it to read
            // `renaming` back: SwiftUI clears `isPresented` on dismissal *before* the
            // button runs, so a rename reaching for the state would find it already nil.
            .alert("Rename gym", isPresented: Binding(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            ), presenting: renaming) { gym in
                TextField("Name", text: $renamed)
                Button("Cancel", role: .cancel) {}
                Button("Rename") { gyms.rename(gym, to: renamed) }
            }
        }
    }

    private var list: ManageGymsList {
        ManageGymsList(gyms: gyms.allGyms)
    }

    /// One gym: the name taps to rename, and the machine count taps through to the
    /// machines. Two targets on one row because they are the screen's two directions —
    /// editing this gym, and walking into it — so **both are sized to be hit**: the
    /// count is a two-character label, and a bare one would be a 10-point target beside
    /// a full-width one.
    private func row(_ gym: Gym) -> some View {
        let canDelete = gyms.canDelete(gym)
        return HStack(spacing: 0) {
            Text(gym.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    renamed = gym.name
                    renaming = gym
                }
            NavigationLink(value: gym) {
                // What is in it — which is also what says whether the delete below is
                // offered at all.
                Text("\(gym.machines?.count ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .fixedSize()
        }
        // **The full swipe is the delete, and only where there is nothing to lose.** A
        // gym holding machines has no full swipe at all: archiving is deliberate enough
        // to be worth the second tap, because there is no verb that undoes it.
        .swipeActions(edge: .trailing, allowsFullSwipe: canDelete) {
            if canDelete {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    gyms.delete(gym)
                }
            }
            if !gym.isArchived {
                Button("Archive", systemImage: "archivebox") {
                    gyms.archive(gym)
                }
                .tint(.orange)
            }
        }
    }
}
