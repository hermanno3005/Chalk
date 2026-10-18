import SwiftUI

/// The foot of the home overflow that **both halves carry alike** (the `endurance-home`
/// prototype's verdict): the Gym menu, since the current gym is one gym whichever half you
/// are in, and *Settings…*, which belongs to neither half (ADR-0005). Each half's overflow
/// puts its own rows above this and draws this unchanged, so the two can't drift.
struct SharedOverflow: View {
    let gyms: GymsModel
    let onNewGym: () -> Void
    let onManageGyms: () -> Void
    let onSettings: () -> Void

    var body: some View {
        // The current-gym picker. *Manage gyms…* joins it at the foot of this menu,
        // a direct sibling of *Edit groups* (§7.4, #31).
        GymMenu(gyms: gyms, onNewGym: onNewGym, onManageGyms: onManageGyms)
        Section {
            Button("Settings…", systemImage: "gearshape") { onSettings() }
        }
    }
}
