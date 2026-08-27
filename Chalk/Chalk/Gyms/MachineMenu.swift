import Foundation

/// Every machine for one exercise, **flat and sectioned by gym** — the shape the app's
/// one machine picker draws (SPEC §5.3, §6.4).
///
/// Flat rather than gym-then-machine: picking a machine is one decision, and a gym you
/// have to choose first is a second one on the two-tap log path. The sections are there
/// to read by, not to walk through.
struct MachineMenu {

    /// One gym's machines. `gym` is `nil` for the section holding machines whose gym has
    /// been deleted — never intentionally produced, but they still derive and still have
    /// to be reachable (SPEC §3, invariant 3).
    struct Section: Identifiable {
        let id: UUID
        let gym: Gym?
        let title: String
        let machines: [Machine]
        /// The single section that closes the menu, holding every archived gym's
        /// machines. **Logging on one of these un-archives its gym** — the side effect
        /// lives where the entry is written (`LogSheetModel.save()`), because there is
        /// no `restore` verb: the moment you need a gym back is the moment you are
        /// standing in it (SPEC §7.4).
        let isArchived: Bool
    }

    let sections: [Section]

    var isEmpty: Bool { sections.isEmpty }

    /// Sections in gym recency order, **the current gym first** — it is where you are
    /// standing, so its machines are the ones your thumb is reaching for. Gym-less
    /// machines follow, and the one `Archived` section closes the menu.
    init(machines: [Machine], currentGym: Gym? = nil) {
        var byGym: [UUID: [Machine]] = [:]
        var gyms: [UUID: Gym] = [:]
        var gymless: [Machine] = []
        for machine in machines {
            guard let gym = machine.gym else {
                gymless.append(machine)
                continue
            }
            gyms[gym.id] = gym
            byGym[gym.id, default: []].append(machine)
        }

        let ordered = GymOrder.byRecency(Array(gyms.values), current: currentGym)
        var sections = ordered
            .filter { !$0.isArchived }
            .map { gym in
                Section(
                    id: gym.id,
                    gym: gym,
                    title: gym.name,
                    machines: MachineScope.byRecency(byGym[gym.id] ?? []),
                    isArchived: false
                )
            }

        if !gymless.isEmpty {
            sections.append(Section(
                id: Self.gymlessSectionID,
                gym: nil,
                title: "No gym",
                machines: MachineScope.byRecency(gymless),
                isArchived: false
            ))
        }

        // One `Archived` section at the very end, however many archived gyms it draws
        // from: it is the tail of a picker, not a second gym list.
        let archived = ordered.filter(\.isArchived).flatMap { byGym[$0.id] ?? [] }
        if !archived.isEmpty {
            sections.append(Section(
                id: Self.archivedSectionID,
                gym: nil,
                title: "Archived",
                machines: MachineScope.byRecency(archived),
                isArchived: true
            ))
        }

        self.sections = sections
    }

    /// Stable ids for the two sections that stand for no gym in particular, so `ForEach`
    /// keeps them still across a rebuild.
    private static let gymlessSectionID = UUID(uuidString: "00000000-0000-0000-0000-00000000A000")!
    private static let archivedSectionID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
}
