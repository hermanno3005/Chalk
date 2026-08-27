import Foundation

/// The two sections `Manage gyms…` draws (SPEC §7.4): **the gyms you use, in recency
/// order, and archived ones in a section at the bottom.**
///
/// A type of its own rather than two filters in the sheet, for the same reason
/// `MachineMenu` is one: the sectioning is the rule, and the view is only how it looks.
///
/// **Nothing is pinned here.** The current gym floats to the top of the *picker* because
/// picking is what that menu is for; this screen is a list of every gym you own, and
/// moving the one you are standing in would only make the rows harder to find.
struct ManageGymsList {

    /// The gyms still in use, most recently logged at first.
    let inUse: [Gym]

    /// Archived gyms, which keep every entry they hold. There is no `restore` verb: they
    /// come back when you log at one (SPEC §7.4), so this section is a place to rename,
    /// to walk into, and to empty out — not a waiting room.
    let archived: [Gym]

    init(gyms: [Gym]) {
        inUse = GymOrder.byRecency(gyms.filter { !$0.isArchived })
        archived = GymOrder.byRecency(gyms.filter(\.isArchived))
    }

    var isEmpty: Bool { inUse.isEmpty && archived.isEmpty }
}
