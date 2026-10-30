import Foundation

/// The sections one gym's machine screen draws inside `Manage gyms…` (SPEC §7.4,
/// §13.11): **Strength, then Endurance**, each most recently used first.
///
/// A type of its own rather than two filters in the view, as `ManageGymsList` is: the
/// sectioning is the rule, and the view is only how it looks.
///
/// **It takes a gym and nothing else** — there is no half to filter by. `Manage gyms…` is
/// one screen whichever half's overflow opened it, because a gym is one gym whichever
/// half you are in, and a repair you could only reach from the other half would be a
/// repair you could not find.
struct GymMachinesList {

    /// Which half a section's machines belong to — the machine's exercise's.
    enum Section: Equatable {
        case strength
        case endurance

        var title: String {
            switch self {
            case .strength: String(localized: "Strength")
            case .endurance: String(localized: "Endurance")
            }
        }
    }

    /// The lifts' machines, most recently logged on first.
    let strength: [Machine]

    /// The ergs' machines, most recently logged on first — a machine's recency is its own
    /// half's by construction (SPEC §13.12).
    let endurance: [Machine]

    init(gym: Gym) {
        let machines = gym.machines ?? []
        strength = MachineScope.byRecency(machines.filter { $0.exercise?.isErg != true })
        endurance = MachineScope.byRecency(machines.filter { $0.exercise?.isErg == true })
    }

    /// The sections to draw, **an empty one hidden** — a gym you only row at shows no
    /// empty Strength header above its rower.
    var sections: [Section] {
        [.strength, .endurance].filter { !machines(in: $0).isEmpty }
    }

    func machines(in section: Section) -> [Machine] {
        switch section {
        case .strength: strength
        case .endurance: endurance
        }
    }

    /// Every machine the gym holds, both halves — **the count that decides whether the
    /// hard delete is offered** (`GymsModel.canDelete(_:)`), so it never counts one half.
    var count: Int { strength.count + endurance.count }
}
