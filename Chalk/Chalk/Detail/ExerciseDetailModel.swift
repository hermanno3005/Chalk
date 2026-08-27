import Foundation
import Observation
import SwiftData

/// The exercise detail screen's state: the curve in view, where the scrub sits, and the
/// two mutations the overflow menu owns (SPEC §5.1–5.2, §5.4–5.5).
///
/// **The screen has two shapes** (SPEC §5.3). A free-weight exercise derives from every
/// entry it has; a gym-bound one derives from **one machine's entries only**, chosen by
/// the qualifier. `RepMaxCurve` takes its scope from the caller, so switching machines is
/// a different array rather than a different derivation.
@Observable
final class ExerciseDetailModel {

    /// What the readout above the curve says. Absent altogether when there is no curve
    /// at all — the zero-entry screen has no readout (SPEC §5.4).
    struct Readout: Equatable {
        /// The selected rep count, the `N` in `best for N reps`.
        let reps: Int
        /// `best[N]`, the large number — **and nil where that cell is unproven.** An
        /// absent cell is "not yet proven", never zero (SPEC §4), so the readout shows
        /// an absence rather than a number from somewhere else.
        let weight: Double?
        /// Entries with `reps >= N`, the `M` in `· M records ›`.
        let entriesBehind: Int
    }

    let exercise: Exercise

    private(set) var curve = RepMaxCurve(entries: [])

    /// Whether this exercise's load transfers between gyms. **The qualifier exists only
    /// where it does not** — a free-weight exercise shows no qualifier at all, not a
    /// disabled one and not a placeholder (SPEC §5.3).
    private(set) var isGymBound = false

    /// The machine the screen is scoped to, and every machine it could be scoped to —
    /// both empty for a free-weight exercise. `machine` is `nil` for a gym-bound exercise
    /// with no machines yet, which is the empty state until the first log creates one.
    private(set) var machine: Machine?
    private(set) var machines: [Machine] = []

    /// The qualifier's rows: every machine for this exercise, flat, sectioned by gym
    /// (SPEC §5.3). Built on refresh rather than behind `var body`, as the library's
    /// ordering is (§7.2, hazard 3).
    private(set) var machineMenu = MachineMenu(machines: [])

    /// The exercise's name and how many entries it holds, **read once and kept here**
    /// rather than off the model object. The screen stays on-stack for a frame or two
    /// after a delete, and a deleted `Exercise` is no longer a thing to ask.
    private(set) var name = ""
    private(set) var entryCount = 0

    /// Where the scrub sits, on the fixed 1–12 axis. **Sticky**: `chartXSelection` clears
    /// its binding the moment a finger lifts, so this holds the last real value rather
    /// than following it back to nil (SPEC §5.2).
    private(set) var selectedReps = ExerciseDetailModel.defaultReps

    @ObservationIgnored private let context: ModelContext
    /// Where the current gym lives. **Consulted upstream of the screen and nowhere
    /// else**: it decides which machine this screen opens scoped to, and the log sheet
    /// never asks it (SPEC §6.4).
    @ObservationIgnored private let gyms: GymsModel
    @ObservationIgnored private let onLibraryChange: () -> Void

    /// The rep count the screen opens on (SPEC §5.2) — held even by an exercise with no
    /// `best[5]`, which reads as the absence it is rather than sliding to a cell that
    /// does have a number.
    private static let defaultReps = 5

    init(
        exercise: Exercise,
        context: ModelContext,
        gyms: GymsModel,
        onLibraryChange: @escaping () -> Void = {}
    ) {
        self.exercise = exercise
        self.context = context
        self.gyms = gyms
        self.onLibraryChange = onLibraryChange
        refresh()
    }

    /// Whether anything is drawn where the chart goes. A newly created exercise gets
    /// short text and the Log bar instead — no axes, no flat line, no ghost, because a
    /// chart frame with no data implies numbers that do not exist (SPEC §5.4).
    var hasCurve: Bool { !curve.best.isEmpty }

    /// Whether this is a gym-bound exercise that has never been logged anywhere, so
    /// there is no machine for this caller to hand the sheet.
    ///
    /// **It does not stop you logging.** The sheet opens with its caption reading unset
    /// and `New machine here` in the picker underneath — the one hole no caller can
    /// close (SPEC §6.4) — and refuses to save until a machine resolves (§3, invariant 4).
    var needsFirstMachine: Bool { isGymBound && machine == nil }

    var readout: Readout? {
        guard hasCurve else { return nil }
        return Readout(
            reps: selectedReps,
            weight: curve.best[selectedReps],
            entriesBehind: curve.entriesBehind[selectedReps] ?? 0
        )
    }

    /// The destructive confirmation, phrased as the outcome with its count (SPEC §5.5).
    /// An exercise with nothing logged is not asked about entries it does not have.
    var deleteConfirmation: String {
        guard entryCount > 0 else { return "Delete \(name)?" }
        let entries = entryCount == 1 ? "1 entry" : "\(entryCount) entries"
        return "Delete \(name) and its \(entries)?"
    }

    /// Re-scopes the screen to another machine and **re-derives the whole curve**
    /// (SPEC §5.3). Nothing is cached, so this is a re-read and not an invalidation.
    ///
    /// The scrub stays where it is: you are comparing the same rep count across two
    /// machines, which is the whole reason to switch.
    func select(_ machine: Machine) {
        guard isGymBound, machine.exercise?.id == exercise.id else { return }
        self.machine = machine
        refresh()
    }

    /// Moves the scrub. `nil` — which is what `chartXSelection` writes back on lift — is
    /// ignored, which is the whole of stickiness. The axis is fixed at 1–12, so a
    /// selection off either end is pulled back onto it.
    func select(_ reps: Int?) {
        guard let reps else { return }
        selectedReps = min(
            max(reps, RepMaxCurve.repRange.lowerBound),
            RepMaxCurve.repRange.upperBound
        )
    }

    /// Cosmetic; identity is the UUID (SPEC §5.5). A blank name is not a rename.
    func rename(to newName: String) {
        let newName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != exercise.name else { return }
        exercise.name = newName
        name = newName
        save()
        onLibraryChange()
    }

    /// Cascades to the exercise's entries and machines through the schema's own delete
    /// rules (SPEC §3). No undo.
    func delete() {
        context.delete(exercise)
        save()
        onLibraryChange()
    }

    /// The log sheet over this exercise, wired to put the curve back in step when it
    /// writes (SPEC §6.7). The context stays private: the sheet is handed one rather
    /// than reaching for the environment's, so it writes where this screen reads.
    ///
    /// **And the library behind it**: an entry logged here is the newest in the store, so
    /// the resume card, the tile subtitle and the recency order are all stale from the
    /// moment it lands (#25). This is the commoner logging path of the two, so it is the
    /// one that must not leave a wrong number behind the back button.
    /// **The sheet never resolves a machine — this caller does** (SPEC §6.4), and what
    /// it hands over is the qualifier's own machine, so resolution costs zero taps.
    func logSheet(onSave: @escaping () -> Void) -> LogSheetModel {
        LogSheetModel(
            exercise: exercise,
            machine: machine,
            context: context,
            gyms: gyms
        ) { [weak self] in
            self?.backInStep()
            onSave()
        }
    }

    /// The history sheet over the cell the readout is showing (SPEC §5.6), wired to put
    /// this screen and the library behind it back in step when it edits or deletes.
    /// **The scrub decides which cell**: the sheet is opened from the number in view, so
    /// it takes the rep count rather than reading it back off a screen that has moved on.
    ///
    /// **Nil on an unproven cell.** The sheet is only ever reachable from a cell that
    /// exists (SPEC §9), so a rep count nothing has reached has no history to explain —
    /// and an empty list of the entries behind a number that is not there would be a
    /// screen state the app does not have.
    func historySheet() -> HistorySheetModel? {
        guard readout?.weight != nil else { return nil }
        return HistorySheetModel(
            exercise: exercise,
            machine: machine,
            atLeast: selectedReps,
            context: context,
            gyms: gyms
        ) { [weak self] in
            self?.backInStep()
        }
    }

    /// What every write from a sheet over this screen has to put right: the curve here,
    /// and the resume card, tile subtitle and recency order in the library behind it.
    private func backInStep() {
        refresh()
        onLibraryChange()
    }

    /// Re-reads the exercise and re-derives the whole curve. Called at init, and again
    /// by the log sheet when it writes an entry (#24).
    ///
    /// **The opening cascade only runs while the screen is scoped to nothing** — at
    /// init, and again if the scoped machine goes. It picks where the screen *starts*
    /// (§5.3); re-running it on every write would drag the screen off the machine the
    /// qualifier switched to, exactly as re-reading `chartXSelection` would drag the
    /// scrub back off the rep count your finger left it on.
    func refresh() {
        name = exercise.name
        entryCount = exercise.entries?.count ?? 0
        isGymBound = exercise.isGymBound

        if isGymBound {
            machines = MachineScope.byRecency(exercise.machines ?? [])
            if machine == nil || !machines.contains(where: { $0 === machine }) {
                machine = MachineScope.opening(machines: machines, currentGym: gyms.currentGym)
            }
            machineMenu = MachineMenu(machines: machines, currentGym: gyms.currentGym)
        } else {
            machines = []
            machine = nil
            machineMenu = MachineMenu(machines: [])
        }

        curve = RepMaxCurve(entries: MachineScope.entries(of: exercise, on: machine))
    }

    private func save() {
        // As in `LibraryModel`: v1 has no error state past §3's container failure and no
        // network, so there is nothing to report and nothing to retry.
        try? context.save()
    }
}
