import Foundation
import Observation
import SwiftData

/// The `reps >= N` history sheet's state (SPEC §5.6): every entry that can determine
/// `best[N]`, newest first, with the one currently setting it flagged.
///
/// **The only place an entry can be edited or deleted.** There is no all-entries log
/// screen; the curve is how you find a bad entry, and this sheet is what it opens.
///
/// It **mirrors the derivation rule rather than restating it** — `reps >= N` is the same
/// filter `RepMaxCurve` sweeps, which is what makes the list sufficient: a backfilled
/// cell shows the higher-rep lifts that floored it, and a sub-best entry is visible,
/// confirming the log landed.
///
/// **It lists the cell's entries in the scope the screen is in** (SPEC §5.6): every entry
/// the exercise has for a free-weight one, one machine's for a gym-bound one. Scoping is
/// a different array, not a different rule (§5.3).
@Observable
final class HistorySheetModel: Identifiable {

    /// One line of history: the words on it copied off the entry at the moment the list
    /// was built, and the entry itself alongside them for the two verbs that act on it.
    struct Row: Identifiable {
        let id: UUID
        let lift: String
        /// The day, in the words the tiles and the resume card use.
        let day: String
        /// Whether this is the entry currently setting `best[N]`.
        let isBest: Bool
        /// The machine the entry was logged on, for a gym-bound exercise (SPEC §5.6).
        /// `nil` for a free-weight one, which has no machine to name.
        let machine: String?

        /// The entry the row stands for, which edit and delete act on. Held rather than
        /// looked up again: the row is the thing your thumb is on. **Not for reading
        /// through** — the list is rebuilt on every write, so the words above are the
        /// ones to draw.
        fileprivate let entry: Entry
    }

    let id = UUID()

    @ObservationIgnored private let exercise: Exercise

    /// The machine the sheet is scoped to — the detail screen's own, and `nil` for a
    /// free-weight exercise. The sheet mirrors the cell it was opened from, so it reads
    /// exactly what that cell derived from.
    @ObservationIgnored private let machine: Machine?

    /// The `N` in `reps >= N`: the cell the sheet was opened from.
    @ObservationIgnored private let reps: Int

    private(set) var rows: [Row] = []

    @ObservationIgnored private let context: ModelContext
    /// The gyms, carried through to the log sheet an edited row opens: its caption's
    /// picker is sectioned by gym, and **an edit never moves the current gym** (SPEC
    /// §6.4). Nothing on this sheet reads them.
    @ObservationIgnored private let gyms: GymsModel
    /// The screens behind the sheet — the detail curve and the library — which every
    /// write here has to put back in step.
    @ObservationIgnored private let onChange: () -> Void

    init(
        exercise: Exercise,
        machine: Machine? = nil,
        atLeast reps: Int,
        context: ModelContext,
        gyms: GymsModel,
        onChange: @escaping () -> Void = {}
    ) {
        self.exercise = exercise
        self.machine = machine
        self.reps = reps
        self.context = context
        self.gyms = gyms
        self.onChange = onChange
        refresh()
    }

    /// The sheet's title: the filter, said out loud, so the list is never mistaken for
    /// the entries at exactly `N` reps.
    var title: String { reps == 1 ? "1 rep and above" : "\(reps) reps and above" }

    /// **The sheet has outlived the cell it was opened from.** Reachable two ways —
    /// deleting the last row, or editing one below the threshold — and neither is a
    /// special case: the sheet exists for as long as there is something to explain.
    var isEmpty: Bool { rows.isEmpty }

    /// The log sheet over one row, seeded from **that** entry rather than your most
    /// recent one, presented as an edit (SPEC §6.6). **No new sheet is designed.**
    ///
    /// `onSave` is the brief confirmation §6.7 asks for, and it belongs to this sheet
    /// rather than the detail screen: an edit is saved with the history list in view and
    /// the detail screen two layers down, where a flash would go unseen.
    ///
    /// **The machine comes off the row's own entry** (SPEC §6.4) — the entry being
    /// edited, not the scope this list is in, so correcting a mislabelled one starts
    /// from what it actually says.
    func editSheet(for row: Row, onSave: @escaping () -> Void = {}) -> LogSheetModel {
        LogSheetModel(
            exercise: exercise,
            machine: row.entry.machine,
            editing: row.entry,
            context: context,
            gyms: gyms
        ) { [weak self] in
            self?.refresh()
            self?.onChange()
            onSave()
        }
    }

    /// Swipe left → Delete, with full-swipe disabled in the view so this always takes
    /// two deliberate gestures (SPEC §5.6). No confirmation, no undo, and **no entry is
    /// a special case** — deleting the only entry, or the one seeding the ghost, needs
    /// no guard here. Lowering a rep-max is the derivation working, not data loss.
    func delete(_ row: Row) {
        context.delete(row.entry)
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        refresh()
        onChange()
    }

    /// Re-reads the entries and rebuilds the list. Called at init, and again by every
    /// edit and delete — including the edit that drops its own row out of the filter.
    func refresh() {
        // The same `reps >= N` scope the curve derives that cell from, read off the
        // derivation rather than filtered again here (SPEC §5.6).
        let scope = RepMaxCurve.entries(
            atLeast: reps,
            in: MachineScope.entries(of: exercise, on: machine)
        )
        // The entry holding `best[N]`: where two share the weight, the older one set it,
        // and matching it later does not take the record off it.
        let best = scope.map(\.weight).max()
        let setter = scope.filter { $0.weight == best }.min { $0.date < $1.date }

        rows = scope.sorted { $0.date > $1.date }.compactMap { entry in
            // The same words the tiles and the resume card use, split in two: the
            // numbers lead the row and the day sits at its end.
            guard let lift = LastEntry(entry) else { return nil }
            return Row(
                id: entry.id,
                lift: lift.lift,
                day: lift.day(),
                isBest: entry === setter,
                machine: entry.machine?.caption,
                entry: entry
            )
        }
    }
}
