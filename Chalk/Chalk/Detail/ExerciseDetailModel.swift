import Foundation
import Observation
import SwiftData

/// The exercise detail screen's state: the curve in view, where the scrub sits, and the
/// two mutations the overflow menu owns (SPEC §5.1–5.2, §5.4–5.5).
///
/// **Free-weight only for now** — the scope is every entry the exercise has. The machine
/// qualifier re-scopes it to one machine's entries and re-derives the whole curve (§5.3,
/// #26); `RepMaxCurve` already takes its scope from the caller, so that lands here as a
/// different array, not a different derivation.
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
    @ObservationIgnored private let onLibraryChange: () -> Void

    /// The rep count the screen opens on (SPEC §5.2) — held even by an exercise with no
    /// `best[5]`, which reads as the absence it is rather than sliding to a cell that
    /// does have a number.
    private static let defaultReps = 5

    init(exercise: Exercise, context: ModelContext, onLibraryChange: @escaping () -> Void = {}) {
        self.exercise = exercise
        self.context = context
        self.onLibraryChange = onLibraryChange
        refresh()
    }

    /// Whether anything is drawn where the chart goes. A newly created exercise gets
    /// short text and the Log bar instead — no axes, no flat line, no ghost, because a
    /// chart frame with no data implies numbers that do not exist (SPEC §5.4).
    var hasCurve: Bool { !curve.best.isEmpty }

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
    func logSheet(onSave: @escaping () -> Void) -> LogSheetModel {
        LogSheetModel(exercise: exercise, context: context) { [weak self] in
            self?.refresh()
            onSave()
        }
    }

    /// Re-reads the exercise and re-derives the whole curve. Called at init, and again
    /// by the log sheet when it writes an entry (#24).
    func refresh() {
        name = exercise.name
        entryCount = exercise.entries?.count ?? 0
        curve = RepMaxCurve(entries: exercise.entries ?? [])
    }

    private func save() {
        // As in `LibraryModel`: v1 has no error state past §3's container failure and no
        // network, so there is nothing to report and nothing to retry.
        try? context.save()
    }
}
