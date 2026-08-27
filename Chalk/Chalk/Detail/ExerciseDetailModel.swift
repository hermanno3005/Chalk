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

    /// Your numbers on a sibling machine, where the one in scope has none of its own —
    /// the line the empty state carries (SPEC §5.4). `nil` for a free-weight exercise,
    /// for a machine with history, and wherever the sibling has no `best[5]` to quote.
    ///
    /// **The only thing on this screen that reads another machine's entries**, and a
    /// distinct lookup rather than part of `RepMaxCurve` over the machine in view: it is
    /// text, never a shape on the chart.
    private(set) var hint: MachineHint?

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
    /// never asks it (SPEC §6.4). Readable so the two doors this screen opens onto a gym
    /// — the log sheet and `Change kind`'s machine prompt — are handed the same one.
    @ObservationIgnored let gyms: GymsModel
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

    /// `Change kind` over this exercise — the words the confirmation and the machine
    /// prompt say (SPEC §8).
    var kindChange: KindChange { KindChange(exercise: exercise) }

    /// **Free-weight → gym-bound**, with the one machine the existing entries belong to
    /// (SPEC §8). The machine is created at `gym` — a free-weight exercise has none to
    /// pick from, which is why the prompt asks for a gym and a name rather than drawing
    /// the machine picker over an empty list.
    ///
    /// **Every existing entry gets that machine**, wholesale: the whole point of the
    /// prompt is that there is no orphan and no "unknown machine" bucket to tidy later
    /// (SPEC §3, invariant 4).
    ///
    /// `name` is the same optional one-field answer `New machine here` asks for, `nil`
    /// where you skipped it.
    func makeGymBound(at gym: Gym, named name: String?) {
        guard !exercise.isGymBound else { return }

        let machine = Machine(
            label: Machine.label(from: name),
            exercise: exercise,
            gym: gym
        )
        context.insert(machine)
        for entry in exercise.entries ?? [] {
            entry.machine = machine
        }
        exercise.kind = ExerciseKind.gymBound.rawValue
        save()

        // The screen opens on the machine the entries just landed on rather than on
        // whatever the opening cascade would pick — it is the only one there is.
        self.machine = machine
        refresh()
        onLibraryChange()
    }

    /// **Free-weight → gym-bound with nothing logged**, where there is no entry to place
    /// and so no machine to ask about (SPEC §8). It lands in the empty state the app
    /// already has: the qualifier reads as unset until the first log creates one (§5.3).
    func makeGymBound() {
        guard !exercise.isGymBound, (exercise.entries ?? []).isEmpty else { return }

        exercise.kind = ExerciseKind.gymBound.rawValue
        save()
        refresh()
        onLibraryChange()
    }

    /// **Gym-bound → free-weight** (SPEC §8): pool everything. Entries keep their
    /// exercise and **nullify their machine link**; the now-meaningless `Machine` rows
    /// are deleted.
    ///
    /// > **The same cascade hazard as the merge.** Deletion runs from `Machine` to its
    /// > entries (SPEC §3), so the order below is load-bearing: every entry is detached
    /// > and **flushed to the store before any machine row goes**. This is the second
    /// > write in the app whose save error is not swallowed — everywhere else the change
    /// > simply waits in the context for the next save, but here the next statement
    /// > destroys history.
    ///
    /// **A machine still holding an entry after that flush is left standing.** In a store
    /// this app wrote there is none — every entry it holds is one of the exercise's, and
    /// they were all just detached — so the guard only fires over a row that arrived some
    /// other way, holding an entry with no exercise of its own (SPEC §3, invariant 2).
    /// What it leaves behind is a machine the free-weight screen never draws; what
    /// dropping it would leave behind is an entry that no longer exists. **A stranded row
    /// is a nuisance; a lost curve is not.**
    ///
    /// Nothing is recomputed: no rep-max is stored, so the pooled curve is simply correct
    /// on the next read (ADR-0002).
    func makeFreeWeight() {
        guard exercise.isGymBound else { return }

        let machines = exercise.machines ?? []
        // The exercise's own entries, and no others: an entry with no exercise is
        // treated as non-existent — never repaired, never surfaced, never counted
        // (SPEC §3, invariant 2) — so this does not reach through the machines to go
        // looking for one.
        for entry in exercise.entries ?? [] {
            entry.machine = nil
        }
        exercise.kind = ExerciseKind.freeWeight.rawValue
        do {
            try context.save()
        } catch {
            // Nothing reached the store, so the entries are still their machines' and
            // deleting one would cascade over them. The flip is abandoned whole rather
            // than left half-applied in the context, where a later save would commit
            // the kind without the detaching and leave a free-weight exercise holding
            // machines. `rollback()` discards everything unsaved on this context, which
            // here is this flip: every other write in the app saves as it goes.
            context.rollback()
            refresh()
            return
        }

        for machine in machines where (machine.entries ?? []).isEmpty {
            context.delete(machine)
        }
        save()

        refresh()
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
        hint = MachineHint.lookUp(exercise, scopedTo: machine)
    }

    private func save() {
        // As in `LibraryModel`: v1 has no error state past §3's container failure and no
        // network, so there is nothing to report and nothing to retry.
        try? context.save()
    }
}
