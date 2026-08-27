import SwiftUI

/// The current-gym picker, in the library's overflow (SPEC §7.4).
///
/// **Ordered by recency — when you last logged an entry there, most recent first, the
/// current gym pinned to the top.** Derived from entries: no stored index, no
/// maintenance, and no auto-archive rule. The two or three gyms you actually use float;
/// the holiday gym sinks on its own.
///
/// `Manage gyms…` sits at its foot as a direct sibling of *Edit groups* (#31).
struct GymMenu: View {
    let gyms: GymsModel
    let onNewGym: () -> Void
    /// `Manage gyms…` — the one admin surface (SPEC §7.4), which is why this menu is
    /// drawn in the library's overflow and nowhere else. **Log-time menus stay pure
    /// pickers**: nothing destructive belongs one slip away from the log path, so the
    /// log sheet reaches for `MachinePicker` rather than for this.
    let onManageGyms: () -> Void

    var body: some View {
        Menu {
            ForEach(gyms.gyms, id: \.id) { gym in
                Button {
                    gyms.select(gym)
                } label: {
                    if gym === gyms.currentGym {
                        Label(gym.name, systemImage: "checkmark")
                    } else {
                        Text(gym.name)
                    }
                }
            }
            Section {
                Button("New gym…", systemImage: "plus") { onNewGym() }
                Button("Manage gyms…", systemImage: "building.2.crop.circle") { onManageGyms() }
            }
        } label: {
            // The label says where you are, because that is the answer you came for —
            // the picker underneath is how you change it.
            Label(gyms.currentGym?.name ?? "Gym", systemImage: "building.2")
        }
    }
}
