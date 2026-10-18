import Foundation
import Observation
import SwiftData

/// The erg detail screen's state (SPEC §13.8), beside `ExerciseDetailModel` and reached
/// from the library model as `detail(for:)` is.
///
/// **Bare for now**: the erg's name, the machine qualifier on a gym-bound erg, §5.4's
/// empty state, the Log bar's lap-list sheet, and the overflow's lifetime operations —
/// Rename, *Change unit…* and Delete. The zone line, readout, hint, goal and the other
/// sheets join it in later tickets.
@Observable
final class ErgDetailModel {

    let erg: Exercise

    /// Read once and kept here rather than off the model object, as
    /// `ExerciseDetailModel` does: the screen stays on-stack for a frame or two after a
    /// delete, and a deleted `Exercise` is no longer a thing to ask.
    private(set) var name = ""
    private(set) var unit: ErgUnit?
    private(set) var entryCount = 0

    /// Whether this erg's numbers are kept per machine. **The qualifier exists only
    /// where they are** — a transferable erg shows no qualifier at all, not a disabled
    /// one and not a placeholder (SPEC §5.3, §13.8).
    private(set) var isGymBound = false

    /// The machine the screen is scoped to, and every machine it could be scoped to —
    /// both empty on a transferable erg. `machine` is `nil` for a gym-bound erg with no
    /// machines yet, until the first block makes one.
    private(set) var machine: Machine?
    private(set) var machines: [Machine] = []

    /// The qualifier's rows: every machine for this erg, flat, sectioned by gym — the
    /// app's one machine menu (SPEC §5.3). Built on refresh rather than behind `var
    /// body`.
    private(set) var machineMenu = MachineMenu(machines: [])

    @ObservationIgnored private let context: ModelContext
    /// The gyms, shared with the library — the machine qualifier and the log sheet read
    /// the current gym through it.
    @ObservationIgnored let gyms: GymsModel
    /// Where this device's heart-rate zones are held, handed on to the sheets that read
    /// them live (ADR-0005).
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let onLibraryChange: () -> Void

    init(
        erg: Exercise,
        context: ModelContext,
        gyms: GymsModel,
        defaults: UserDefaults = .standard,
        onLibraryChange: @escaping () -> Void = {}
    ) {
        self.erg = erg
        self.context = context
        self.gyms = gyms
        self.defaults = defaults
        self.onLibraryChange = onLibraryChange
        refresh()
    }

    /// The lap-list sheet the Log bar opens (SPEC §13.7), **handed the qualifier's
    /// machine** — the sheet never resolves one itself (§6.4). A write re-reads this
    /// screen and puts the library behind it back in step, as §6.7's does.
    ///
    /// A gym-bound erg with no machine yet still opens it: the caption reads
    /// `No machine`, its `New machine here` is where the hole is closed, and Save waits
    /// until it is (SPEC §3, invariant 4).
    func logSheet() -> LapListModel? {
        LapListModel(
            erg: erg,
            machine: machine,
            context: context,
            gyms: gyms,
            defaults: defaults
        ) { [weak self] in
            self?.refresh()
            self?.onLibraryChange()
        }
    }

    /// Whether *Change unit…* is offered: **only while the erg has no entries** (SPEC
    /// §13.6). Absent, not disabled, otherwise — and any entry counts, on the erg or on
    /// one of its machines, valid interval or not, because each is a number logged in
    /// the unit it would reinterpret.
    var canChangeUnit: Bool { entryCount == 0 }

    /// The destructive confirmation, phrased as the outcome with its count (SPEC §5.5).
    var deleteConfirmation: String {
        guard entryCount > 0 else { return "Delete \(name)?" }
        let entries = entryCount == 1 ? "1 entry" : "\(entryCount) entries"
        return "Delete \(name) and its \(entries)?"
    }

    /// Changes the erg's unit, **refused once it has any entry** — there is no repair for
    /// a wrong unit with entries; deleting the erg is the accepted cost (SPEC §13.6).
    ///
    /// **Clears the erg's goal** — the erg's own and every machine's, through
    /// `GoalScope.clear()` — because a goal's intensity is a number in the old unit.
    /// Returns whether the unit changed.
    @discardableResult
    func changeUnit(to newUnit: ErgUnit) -> Bool {
        guard canChangeUnit, erg.isErg else { return false }
        guard newUnit != unit else { return true }

        erg.unit = newUnit.rawValue
        GoalScope.exercise(erg).clear()
        for machine in erg.machines ?? [] {
            GoalScope.machine(machine).clear()
        }
        save()
        refresh()
        onLibraryChange()
        return true
    }

    /// Re-scopes the screen to another machine (SPEC §5.3). Nothing is cached, so this
    /// is a re-read and not an invalidation.
    func select(_ machine: Machine) {
        guard isGymBound, machine.exercise?.id == erg.id else { return }
        self.machine = machine
        refresh()
    }

    /// The qualifier's `New machine here` (SPEC §13.11): the gym is implied by its
    /// section, and the screen re-scopes to the machine. **A name that looks like this
    /// erg's machine at the same gym lands on that machine** rather than a twin, through
    /// the same door as the log sheet's caption (`Machine.made`).
    func createMachine(at gym: Gym, named name: String?) {
        guard isGymBound else { return }
        let machine = Machine.made(for: erg, at: gym, named: name, in: context)
        save()
        self.machine = machine
        refresh()
    }

    /// The near-name warning the qualifier's `New machine here` puts first — this erg's
    /// machine at another gym the name looks like (SPEC §13.11). A same-gym match is not
    /// a warning: `createMachine` picks it.
    func nearModel(named name: String?, at gym: Gym) -> ErgModelMatch? {
        ErgModelMatch.onCreate(name, for: erg, at: gym)
    }

    /// Cosmetic; identity is the UUID (SPEC §5.5). A blank name is not a rename.
    func rename(to newName: String) {
        let newName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != erg.name else { return }
        erg.name = newName
        name = newName
        save()
        onLibraryChange()
    }

    /// Cascades to the erg's entries and machines through the schema's own delete rules
    /// (SPEC §3). No undo.
    func delete() {
        context.delete(erg)
        save()
        onLibraryChange()
    }

    /// Re-reads the erg.
    ///
    /// The count is the erg's entries **and its machines'**: every write holds
    /// `entry.machine?.exercise == entry.exercise` (SPEC §3), so these are one set in a
    /// store this app wrote, and the union only guards one that arrived some other way.
    func refresh() {
        name = erg.name
        unit = erg.ergUnit
        var ids = Set((erg.entries ?? []).map(\.persistentModelID))
        for machine in erg.machines ?? [] {
            ids.formUnion((machine.entries ?? []).map(\.persistentModelID))
        }
        entryCount = ids.count

        // The qualifier, resolved as a gym-bound exercise's is (SPEC §5.3, unchanged):
        // the screen stays on the machine you switched to, and otherwise opens on the
        // current gym's — or, where it holds none, the one most recently logged on.
        isGymBound = erg.isGymBound
        if isGymBound {
            machines = MachineScope.byRecency(erg.machines ?? [])
            if machine == nil || !machines.contains(where: { $0 === machine }) {
                machine = MachineScope.opening(machines: machines, currentGym: gyms.currentGym)
            }
            // The gym you are standing in gets a section even before it holds a machine
            // for this erg: the qualifier's `New machine here` lives in it (§13.11).
            machineMenu = MachineMenu(
                machines: machines,
                currentGym: gyms.currentGym,
                including: [gyms.currentGym].compactMap { $0 }
            )
        } else {
            machine = nil
            machines = []
            machineMenu = MachineMenu(machines: [])
        }
    }

    private func save() {
        // As everywhere else: v1 has no error state past §3's container failure.
        try? context.save()
    }
}
