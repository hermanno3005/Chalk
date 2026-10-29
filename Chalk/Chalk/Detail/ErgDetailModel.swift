import Foundation
import Observation
import SwiftData

/// The erg detail screen's state (SPEC §13.8), beside `ExerciseDetailModel` and reached
/// from the library model as `detail(for:)` is.
///
/// The erg's name, the machine qualifier on a gym-bound erg, **the zone line read one
/// zone at a time** — zone buttons, incline menu, scrub readout, the over-20:00 caption,
/// the zones gate and §5.4's empty state, all through `reading` — the Log bar's lap-list
/// sheet, and the overflow's lifetime operations: Rename, *Change unit…* and Delete. The
/// no-line text, hint, goal and the other sheets join it in later tickets.
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

    /// What the screen reads off the scope in view: the selected zone, duration and
    /// incline, every zone's line, the readout and the over-20:00 caption. **Re-derived on
    /// every refresh** — a write, a machine switch, zones set in Settings — with the
    /// selection carried over, so the screen stays where you left it (SPEC §5.2).
    private(set) var reading = ErgReading(entries: [], zones: nil, unit: nil, distanceUnit: .km, keeping: nil)

    /// The goal on the scope in view — the erg, or the machine the qualifier is on —
    /// judged against the same entries and live zones the line is (SPEC §13.10). Re-read
    /// on every refresh, so a slower visit un-reaches it on the next read.
    private(set) var goal: EnduranceGoal?

    /// What the last unit change said of the goal it cleared — *Your goal of 260 W · 10:00
    /// in Z3 is cleared.* — shown once, then dismissed. Nil when it cleared none.
    var clearedGoalNotice: String?

    /// On a gym-bound erg whose machine in scope has no entries: one dimmed line quoting a
    /// sibling machine's line, under the empty state's text (SPEC §13.8). Never part of
    /// any line.
    private(set) var hint: ErgMachineHint?

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

        // Named in the old unit, before it goes — and said, since nothing else would.
        let scopes = [GoalScope.exercise(erg)] + (erg.machines ?? []).map(GoalScope.machine)
        clearedGoalNotice = EnduranceGoal.clearedNotice(scopes.compactMap {
            $0.enduranceGoal(zones: reading.zones, distanceUnit: reading.distanceUnit)
        })

        erg.unit = newUnit.rawValue
        scopes.forEach { $0.clear() }
        save()
        refresh()
        onLibraryChange()
        return true
    }

    // MARK: - Change kind (SPEC §8, §13.11)

    /// `Change kind` over this erg — the words the confirmation and *Which machine is
    /// this on?* say. **Only the scope changes**: unit and incline are untouched.
    var kindChange: KindChange { KindChange(exercise: erg, distanceUnit: reading.distanceUnit) }

    /// **Transferable → gym-bound**: every entry moves to one new machine at `gym`, and
    /// the screen opens on it — the only one there is.
    ///
    /// **The erg's goal moves there too**, keeping when it was set, and leaves the erg in
    /// the same save: a gym-bound erg holds no goal of its own (SPEC §13.11).
    func makeGymBound(at gym: Gym, named name: String?) {
        guard erg.isErg, !erg.isGymBound else { return }
        let machine = kindChange.placeEntries(at: gym, named: name, in: context)
        GoalScope.machine(machine).takeGoal(from: .exercise(erg))
        save()
        self.machine = machine
        refresh()
        onLibraryChange()
    }

    /// **Transferable → gym-bound with nothing to place**: the empty state a gym-bound
    /// erg already has, until the first block makes a machine (SPEC §5.3).
    func makeGymBound() {
        guard erg.isErg, !erg.isGymBound, !kindChange.needsAMachine else { return }
        erg.kind = ExerciseKind.gymBound.rawValue
        save()
        refresh()
        onLibraryChange()
    }

    /// **Gym-bound → transferable**: every machine pooled, the machines deleted, and no
    /// interval lost to the cascade — reassigned and flushed first (ADR-0002).
    ///
    /// **The most recently set machine goal survives onto the erg**, keeping its own
    /// `goalSetAt`, before any machine goes; the cascade takes the others with their
    /// machines, as the confirmation said it would (SPEC §13.11).
    func makeTransferable() {
        guard erg.isErg, erg.isGymBound else { return }
        let change = kindChange
        if let keeping = change.machineKeepingGoal {
            GoalScope.exercise(erg).takeGoal(from: .machine(keeping))
        }
        guard change.pool(in: context) else {
            refresh()
            return
        }
        refresh()
        onLibraryChange()
    }

    /// Re-scopes the screen to another machine (SPEC §5.3). Nothing is cached, so this
    /// is a re-read and not an invalidation.
    func select(_ machine: Machine) {
        guard isGymBound, machine.exercise?.id == erg.id else { return }
        self.machine = machine
        refresh()
    }

    // MARK: - Reading the zone line

    /// Where the screen is looking; nil with zones not set or nothing logged on the scope.
    var selection: ErgReading.Selection? { reading.selection }

    var readout: ErgReading.Readout? { reading.readout }

    /// The scale every speed on this screen is written on, read live on every refresh.
    var distanceUnit: DistanceUnit { reading.distanceUnit }

    /// Zones not set: a *Set your heart-rate zones* row, opening Settings, stands in place
    /// of the zone buttons, readout and line (SPEC §13.8). The Log bar works as normal.
    var needsZones: Bool { reading.zones == nil }

    /// Nothing logged on the scope in view — §5.4's empty state. A gym-bound erg's scope
    /// is the qualifier's machine, so a machine with nothing on it is empty however much
    /// its siblings hold.
    var isEmpty: Bool { reading.isEmpty }

    /// The incline menu's choices — every incline logged on this scope, on a speed erg
    /// only. Empty on any other unit, which has no menu.
    var inclines: [Double] { reading.inclines }

    /// The dimmed `2 entries over 20:00` caption under the line; nil without one.
    var overTheAxisCaption: String? { reading.overTheAxisCaption }

    /// The text and quotes in place of the chart when the selected zone has no line here;
    /// nil when it has one, or there is nothing to select.
    var noLine: ErgNoLine? { ErgNoLine(reading, place: isGymBound ? "machine" : "erg") }

    /// Whether a zone has a line on this scope and incline. A zone without one is dimmed
    /// but still tappable.
    func hasLine(_ zone: Int) -> Bool { reading.hasLine(zone) }

    /// A zone button: every zone is tappable, a dimmed one too.
    func select(zone: Int) { reading.select(zone: zone) }

    /// The scrub: snapped to a duration done, and sticky — `nil` on lift is ignored.
    func select(duration: Int?) { reading.select(duration: duration) }

    /// The incline menu, on a speed erg.
    func select(incline: Double) { reading.select(incline: incline) }

    /// The point's sheet the readout and its `Entries 12 ›` row open — **the chart's only door**
    /// (SPEC §13.9) — at the selected duration, zone and incline on this scope. Nil
    /// without a readout: zones not set, or a zone with no line here.
    func historySheet() -> ErgHistoryModel? {
        guard readout != nil, let selection else { return nil }
        return history(.point(duration: selection.duration), selection)
    }

    /// The flat list the over-20:00 caption opens, for the selected zone and incline. Nil
    /// where there is no caption.
    func overTheAxisSheet() -> ErgHistoryModel? {
        guard overTheAxisCaption != nil, let selection else { return nil }
        return history(.overTheAxis, selection)
    }

    private func history(_ listing: ErgHistoryModel.Listing, _ selection: ErgReading.Selection) -> ErgHistoryModel {
        ErgHistoryModel(
            erg: erg,
            machine: machine,
            zone: selection.zone,
            incline: selection.incline,
            listing: listing,
            context: context,
            gyms: gyms,
            defaults: defaults
        ) { [weak self] in
            self?.refresh()
            self?.onLibraryChange()
        }
    }

    /// Settings, opened in place of the zone buttons while zones are not set. The screen
    /// re-reads when it closes: entries logged before the zones join the lines then.
    func settings() -> SettingsModel {
        SettingsModel(defaults: defaults, container: context.container)
    }

    /// Settings has closed: re-reads, and puts the grid behind back in step, since a
    /// relabel or a convert there moves the scale both write in.
    func settingsClosed() {
        refresh()
        onLibraryChange()
    }

    // MARK: - The goal (SPEC §13.10)

    /// Where a goal on the scope in view lives — **nil on a gym-bound erg with no machine
    /// yet**, and never a sibling machine's (§12.6).
    private var goalScope: GoalScope? { GoalScope(exercise: erg, machine: machine) }

    /// The overflow's goal item — **absent, not disabled, until zones are set** and on a
    /// gym-bound erg with no machine: there is nothing a goal could name or nowhere to
    /// hold it.
    var goalMenuLabel: String? {
        guard !needsZones, goalScope != nil else { return nil }
        return goal == nil ? "Set a goal…" : "Change goal…"
    }

    /// The line under the readout, whatever zone is selected; nil without a goal.
    var goalLine: GoalLine? { goal.map(GoalLine.init(endurance:)) }

    /// The goal sheet over the scope in view, seeded from where the screen is scrubbed,
    /// wired to put this screen — and the resume card's ring behind it — back in step
    /// when it sets or clears. Nil behind either gate.
    func goalSheet() -> EnduranceGoalSheetModel? {
        guard let goalScope else { return nil }
        return EnduranceGoalSheetModel(
            scope: goalScope,
            selection: selection,
            zones: reading.zones,
            distanceUnit: reading.distanceUnit,
            context: context
        ) { [weak self] in
            self?.refresh()
            self?.onLibraryChange()
        }
    }

    // MARK: - Machines

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

        // The zones and the distance unit are read live, never cached (ADR-0005):
        // Settings can move both behind this screen.
        reading = ErgReading(
            entries: MachineScope.entries(of: erg, on: machine),
            zones: HeartRateZones(defaults: defaults),
            unit: unit,
            distanceUnit: DistanceUnit(defaults: defaults),
            keeping: reading.selection
        )
        hint = ErgMachineHint.lookUp(erg, scopedTo: machine, zones: reading.zones, distanceUnit: reading.distanceUnit)
        goal = goalScope?.enduranceGoal(zones: reading.zones, distanceUnit: reading.distanceUnit)
    }

    private func save() {
        // As everywhere else: v1 has no error state past §3's container failure.
        try? context.save()
    }
}
