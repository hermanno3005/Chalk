import Foundation
import Observation
import SwiftData

/// The two-stage log sheet's state: reps, then weight, one giant number at a time
/// (SPEC §6.1–6.3, §6.5, §6.7).
///
/// **The sheet never resolves a machine — its caller does** (§6.4): it is handed one, it
/// writes the entry onto it, and every number it shows is derived from that machine's
/// entries alone. The caption above the number says which one and is how you correct it,
/// so resolution costs **zero taps** and there is no third stage.
///
/// **The current gym is never consulted to resolve a machine here** (§6.4) — that job is
/// upstream, deciding what the detail screen opens scoped to. The sheet only ever *moves*
/// it, and only while logging.
///
/// **One sheet, two presentations** (SPEC §6.6): handed an entry, it seeds from that
/// entry rather than your most recent one and writes back in place. Reps and weight are
/// editable; the date is not — nothing here can reach it.
///
/// Both numbers are optional because **blank is a real state**: the cold-start weight
/// opens empty rather than guessing a load (§6.3), and the keypad can be cleared back
/// to nothing. Nothing is savable until both are filled (§6.7).
@Observable
final class LogSheetModel: Identifiable {

    let id = UUID()

    /// The line under the number, in its two kinds (SPEC §6.5). Both are one string and
    /// they differ only in what stands behind them — which is exactly what the sheet
    /// draws differently.
    enum Verdict: Equatable {
        /// One of the four states derived from **this** machine's entries: your own
        /// numbers, judged against the weight on screen.
        case measured(String)
        /// The fifth state: the **machine hint**, your numbers on a sibling machine.
        /// Drawn visibly softer than a real verdict, because it is not one — nothing
        /// here was lifted on the machine in front of you.
        case hint(String)

        var text: String {
            switch self {
            case .measured(let text), .hint(let text): return text
            }
        }

        var isHint: Bool {
            if case .hint = self { return true }
            return false
        }
    }

    let exercise: Exercise

    /// The machine the entry is written onto — **the caller's answer, never this
    /// sheet's** (SPEC §6.4). `nil` for a free-weight exercise, which has no machine to
    /// carry, and for the one gym-bound case no caller *can* answer: the first log at a
    /// gym with no machine for this exercise, which `New machine here` closes. An entry
    /// with no machine is still not producible (SPEC §3, invariant 4) — `canSave`
    /// refuses one.
    private(set) var machine: Machine?

    /// The rows the caption opens: the same flat menu the detail screen's qualifier
    /// draws (SPEC §5.3), plus a section for every gym holding no machine for this
    /// exercise yet, so `New machine here` is reachable at the gym you are standing in.
    /// Empty for a free-weight exercise, which carries no machine row at all.
    private(set) var machineMenu = MachineMenu(machines: [])

    /// The entry being corrected, or nil for a new one. **The only difference between
    /// the two presentations** — everything below this line is the same sheet.
    @ObservationIgnored private let editing: Entry?

    /// The giant number itself — staging, steppers, keypad — **shared with the goal
    /// sheet and carrying none of this sheet's meaning** (#73). Everything below reads
    /// it; only the seeding rules decide what goes into it.
    var number = TwoStageNumber(reps: nil, weight: nil)

    /// The gyms made from this sheet's own `New gym…`, which hold no machine for this
    /// exercise yet and still need a section to make one in.
    @ObservationIgnored private var addedHere: [Gym] = []

    @ObservationIgnored private let context: ModelContext
    /// The gyms, for the three things the sheet does with them: sectioning the picker,
    /// **moving the current gym when you pick a machine at another one while logging**
    /// (SPEC §6.4), and standing behind the `New gym…` row's own field. Never read to
    /// decide which machine this sheet is on — that is the caller's answer.
    @ObservationIgnored let gyms: GymsModel
    @ObservationIgnored private let onSave: () -> Void
    /// The entries the verdict is derived against — read once, at open. They are the
    /// picture behind the sheet, and the sheet closes on the write that would change it.
    @ObservationIgnored private var entries: [Entry] = []

    /// Your numbers on the sibling machine, where the one in scope has none of its own
    /// (SPEC §6.5) — read alongside the entries, and re-read when the caption corrects
    /// the machine. **A lookup, never a seed**: it fills no number on this sheet.
    @ObservationIgnored private var hint: MachineHint?

    /// The cold-start rep count (SPEC §6.3). There is no cold-start weight: the app
    /// never guesses a load it cannot back up.
    private static let defaultReps = 5

    init(
        exercise: Exercise,
        machine: Machine? = nil,
        editing: Entry? = nil,
        context: ModelContext,
        gyms: GymsModel,
        onSave: @escaping () -> Void = {}
    ) {
        self.exercise = exercise
        self.machine = machine
        self.editing = editing
        self.context = context
        self.gyms = gyms
        self.onSave = onSave
        rescopeEntries()

        if let editing {
            // Seeded from *that* entry — the numbers you tapped, ready to be corrected.
            number = TwoStageNumber(reps: editing.reps, weight: editing.weight)
        } else {
            number = TwoStageNumber(
                // **Reps seed from your most recent entry on any machine** — rep counts
                // transfer between machines in a way loads do not (SPEC §6.3).
                reps: LastEntry.latest(in: entriesOnAnyMachine)?.reps ?? Self.defaultReps,
                // **The weight only from this exact machine**, so no number you have
                // never lifted *there* is ever one tap from Save.
                weight: LastEntry.latest(in: entries)?.weight
            )
        }
        refreshMenu()
    }

    /// The entries the seed and the verdict are read from: the scope the screen behind
    /// the sheet is in (SPEC §5.3) — one machine's for a gym-bound exercise, every one
    /// the exercise has for a free-weight one — minus the entry being corrected, which
    /// is not part of its own verdict (SPEC §6.5).
    private func rescopeEntries() {
        entries = MachineScope.entries(of: exercise, on: machine)
            .filter { $0 !== editing }
        // Off the same array the verdict derives against, so "nothing lifted here" means
        // one thing on this sheet: an edit whose only entry on this machine is the one
        // being corrected is a machine with nothing else to say.
        hint = MachineHint.lookUp(exercise, scopedTo: machine, historyHere: entries)
    }

    /// Every entry for the exercise, whichever machine it was logged on — what the
    /// **reps** seed reads, and the one place the sheet looks past the machine it is on.
    private var entriesOnAnyMachine: [Entry] {
        (exercise.entries ?? []).filter { $0 !== editing }
    }

    // MARK: - What the sheet shows

    /// The day the entry being edited was logged — **and the sheet's only tell that it
    /// is an edit**, which is as much difference as §6.6 asks for. **Shown, not editable** — the sheet
    /// says which lift you are correcting, and offers no way to move it.
    var dateLabel: String? {
        editing.flatMap(LastEntry.init)?.day()
    }

    /// The caption above the giant number — **gym-bound only, and on both stages**
    /// (SPEC §6.4). `nil` for a free-weight exercise, which carries no machine row at
    /// all: not a disabled one, not a placeholder.
    ///
    /// It is never hidden "unless something is odd" — a strip that comes and goes shifts
    /// the layout and stops being trusted. A gym-bound sheet with nothing resolved yet
    /// says so, which is the state the first log at a new gym opens in.
    var machineCaption: String? {
        guard exercise.isGymBound else { return nil }
        return machine?.caption ?? Self.noMachineCaption
    }

    /// What the caption reads before any machine exists — the one case no caller can
    /// resolve, closed by `New machine here` inside the picker (SPEC §6.4).
    static let noMachineCaption = "No machine"

    // The number's own readings, so the verdict and the save read the sheet rather than
    // reaching through it.
    var stage: TwoStageNumber.Stage { number.stage }
    var mode: TwoStageNumber.Mode { number.mode }
    var reps: Int? { number.reps }
    var weight: Double? { number.weight }
    var numberText: String { number.numberText }
    var unitText: String { number.unitText }
    var repsLabel: String { number.repsLabel }

    /// The line under the number, **weight stage only** (SPEC §6.5). Stage one stays
    /// silent: the line is meaningless until both numbers exist, and showing the target
    /// there would turn the sheet into a lookup surface — the detail screen's job.
    ///
    /// **The fifth state is the hint** (SPEC §6.5): where nothing here reaches that rep
    /// count *and* a sibling machine has usable history, the line quotes the sibling
    /// rather than saying `First entry at 5 reps` — which is true, and tells you nothing
    /// at precisely the moment you most need a number. It keeps its own fixed rep count,
    /// because it is a lookup and not a judgement of the weight on screen.
    var verdict: Verdict? {
        guard stage == .weight, let reps else { return nil }
        guard let best = RepMaxCurve.best(atLeast: reps, in: entries) else {
            if let hint {
                return .hint(hint.verdictLine)
            }
            return .measured("First entry at \(reps) reps")
        }
        // A blank weight compares as the nothing it is, which reads as "below".
        let weight = weight ?? 0
        if weight > best {
            return .measured("Beats your \(reps)-rep best by \((weight - best).kilogramsText) kg")
        }
        if weight == best {
            return .measured("Matches your \(reps)-rep best")
        }
        return .measured("Your \(reps)-rep best is \(best.kilogramsText) kg")
    }

    var canAdvance: Bool { number.canAdvance }

    /// `reps >= 1` and `weight > 0` (SPEC §6.7). No upper bound and no outlier
    /// confirmation — a typo is corrected, not prevented.
    /// **A gym-bound exercise must resolve a machine** (SPEC §3, invariant 4): with no
    /// machine there is nothing to write the entry onto, and an unscoped entry pollutes
    /// the derivation forever. The sheet can open in that state — the first log at a new
    /// gym — and this is what holds Save shut until the caption's `New machine here`
    /// resolves one.
    var canSave: Bool { canAdvance && (weight ?? 0) > 0 && (machine != nil || !exercise.isGymBound) }

    // MARK: - The machine

    /// Whether this sheet is correcting an entry rather than writing a new one — **the
    /// one thing stickiness splits on** (SPEC §6.4, §6.6).
    private var isEditing: Bool { editing != nil }

    /// Corrects the machine from the caption's picker. The same verb the detail screen's
    /// qualifier calls, over a sheet instead of a curve.
    ///
    /// **Picking a machine at another gym while logging silently moves the current gym**
    /// — that is what makes "changeable in one tap" mean anything. **While editing it
    /// never does**: fixing a three-week-old entry from your couch must not relabel what
    /// you log next (SPEC §6.4).
    func select(_ machine: Machine) {
        // `entry.machine?.exercise == entry.exercise`, held at every write (SPEC §3,
        // invariant 1), so a machine from another exercise is not a correction.
        guard exercise.isGymBound, machine.exercise?.id == exercise.id else { return }
        // Before the identity check, not after: confirming the machine the caller
        // resolved is exactly the mislabelled-by-stale-sticky-gym case the caption
        // exists to catch, and it moves the current gym like any other pick.
        moveCurrentGym(to: machine.gym)
        // Nothing left to re-seed for the machine already in scope.
        guard machine !== self.machine else { return }
        self.machine = machine
        reseed()
        refreshMenu()
    }

    /// The stickiness half of a pick. **An archived gym is not somewhere you are
    /// standing** — it left the picker (SPEC §7.4), so it becomes the current gym when
    /// the log lands and un-archives it, not when you tap its row.
    private func moveCurrentGym(to gym: Gym?) {
        guard !isEditing, let gym, !gym.isArchived, gym !== gyms.currentGym else { return }
        gyms.select(gym)
    }

    /// `New machine here`: the gym is implied by the section the row sits in, so there is
    /// no gym picker and no second decision — the machine is created and **the sheet
    /// resolves to it** (SPEC §6.4).
    ///
    /// `name` is the optional one-field alert's answer, `nil` where you skipped it. It is
    /// **always asked**, because you cannot know at creation time whether a second
    /// machine is coming.
    func createMachine(at gym: Gym, named name: String?) {
        guard exercise.isGymBound else { return }
        let machine = Machine(
            label: Machine.label(from: name),
            exercise: exercise,
            gym: gym
        )
        context.insert(machine)
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        select(machine)
    }

    /// `New gym…` came back with one. The picker gains its section — **and only its
    /// section**: the machine you are standing at is still the always-asked decision
    /// `New machine here` puts to you (SPEC §6.4).
    func gymCreated(_ gym: Gym) {
        addedHere.append(gym)
        refreshMenu()
    }

    /// What a corrected machine changes: the seed and the verdict move to the machine
    /// you picked. **The weight goes with it and the reps do not** (SPEC §6.3), and an
    /// edit keeps the numbers you came to correct — the machine is the entry's label,
    /// not its lift.
    private func reseed() {
        rescopeEntries()
        guard !isEditing else { return }
        // Where that weight is the number on screen, the weight stage reopens over it —
        // blank with the keypad up, if nothing was lifted on the machine you picked.
        number.seedWeight(LastEntry.latest(in: entries)?.weight)
    }

    /// The picker's rows, rebuilt whenever a machine is made. Sectioned by gym, with the
    /// gyms holding no machine for this exercise yet included: `New machine here` lives
    /// in a gym section, and the gym you are standing in has to have one.
    private func refreshMenu() {
        guard exercise.isGymBound else {
            machineMenu = MachineMenu(machines: [])
            return
        }
        machineMenu = MachineMenu(
            machines: exercise.machines ?? [],
            currentGym: gyms.currentGym,
            including: gymsNeedingASection
        )
    }

    /// The gyms that get a section of their own without holding a machine for this
    /// exercise — **the two `New machine here` has to be reachable in, and no more**.
    /// A section per gym you own would turn a flat one-decision picker into a list to
    /// walk down on the two-tap log path (SPEC §5.3).
    ///
    /// The gym you are standing in is the hole §6.4 names: the first gym-bound log at a
    /// gym with no machine for this exercise. A gym made from this sheet's own
    /// `New gym…` is the same hole one step later, and would otherwise be a door onto
    /// nothing.
    private var gymsNeedingASection: [Gym] {
        [gyms.currentGym].compactMap { $0 } + addedHere
    }

    // MARK: - Staging and input

    func advance() { number.advance() }
    func backToReps() { number.backToReps() }
    func tapNumber() { number.tapNumber() }
    func type(_ key: TwoStageNumber.Key) { number.type(key) }
    func step(_ direction: Int) { number.step(direction) }

    // MARK: - Commit

    /// Writes the entry — a new one, or the one being edited, in place. The caller
    /// closes the sheet: after saving it never stays open
    /// to log again, because sessions are not modelled (SPEC §6.7).
    func save() {
        guard canSave, let reps, let weight else { return }
        if let editing {
            // In place, and the date stays where it was (SPEC §6.6). An edit that drops
            // the entry out of the history sheet it was opened from is that sheet's
            // filter behaving, not something to compensate for here.
            editing.reps = reps
            editing.weight = weight
            // `entry.machine?.exercise == entry.exercise`, maintained at write time on
            // log and on edit alike (SPEC §3, invariant 1).
            //
            // **A corrected machine moves the entry silently** (SPEC §6.4): it leaves
            // the history list you are looking at and both curves change. No
            // confirmation and no toast — the list behind the sheet re-reading is the
            // feedback, exactly as an edit below the `reps >= N` threshold is.
            editing.machine = machine
        } else {
            context.insert(Entry(
                reps: reps,
                weight: weight,
                date: .now,
                exercise: exercise,
                machine: machine
            ))
            // **Logging at an archived gym un-archives it** (SPEC §7.4). There is
            // deliberately no `restore` verb: the one moment you need a gym back is the
            // moment you are standing in it. An *edit* does not do this — correcting a
            // three-week-old entry from your couch is not a visit.
            if let gym = machine?.gym, gym.isArchived {
                gym.isArchived = false
                // And it is now where you are standing, which `select` would not do
                // while the gym was still archived — an archived gym is not somewhere
                // you are (SPEC §7.4), right up until the log that says otherwise.
                gyms.select(gym)
            }
        }
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        onSave()
    }
}
