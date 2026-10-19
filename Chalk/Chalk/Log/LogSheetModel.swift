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

    /// The line under the number, in its three kinds (SPEC §6.5). All are one string and
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
        /// The first state: **saving this would reach the goal** at the sheet's scope.
        /// Drawn in the goal colour behind a full ring, because at the crossing the goal
        /// is the news.
        case goal(String)

        var text: String {
            switch self {
            case .measured(let text), .hint(let text), .goal(let text): return text
            }
        }

        var isHint: Bool {
            if case .hint = self { return true }
            return false
        }
    }

    let exercise: Exercise

    /// The machine the entry is written onto and the caption that corrects it — shared
    /// with the endurance log sheet, so the two halves resolve, move the current gym and
    /// un-archive by one rule (SPEC §6.4, §13.7).
    private var caption: MachineCaption

    /// The machine the entry is written onto — **the caller's answer, never this
    /// sheet's** (SPEC §6.4). `nil` for a free-weight exercise, which has no machine to
    /// carry, and for the one gym-bound case no caller *can* answer: the first log at a
    /// gym with no machine for this exercise, which `New machine here` closes. An entry
    /// with no machine is still not producible (SPEC §3, invariant 4) — `canSave`
    /// refuses one.
    var machine: Machine? { caption.machine }

    /// The rows the caption opens: the same flat menu the detail screen's qualifier
    /// draws (SPEC §5.3), plus a section for every gym holding no machine for this
    /// exercise yet, so `New machine here` is reachable at the gym you are standing in.
    /// Empty for a free-weight exercise, which carries no machine row at all.
    var machineMenu: MachineMenu { caption.menu }

    /// The entry being corrected, or nil for a new one. **The only difference between
    /// the two presentations** — everything below this line is the same sheet.
    @ObservationIgnored private let editing: Entry?

    /// The giant number itself — staging, steppers, keypad — **shared with the goal
    /// sheet and carrying none of this sheet's meaning** (#73). Everything below reads
    /// it; only the seeding rules decide what goes into it.
    var number = TwoStageNumber(reps: nil, weight: nil)

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

    /// The goal at the sheet's scope, judged against the same entries the verdict is —
    /// so an edit is judged against every other entry, never itself — and re-read when
    /// the caption corrects the machine.
    @ObservationIgnored private var goal: Goal?

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
        self.caption = MachineCaption(
            exercise: exercise,
            machine: machine,
            isEditing: editing != nil,
            context: context,
            gyms: gyms
        )
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
        goal = GoalScope(exercise: exercise, machine: machine)?.goal(judgedAgainst: entries)
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
    var machineCaption: String? { caption.text }

    // The number's own readings and verbs, forwarded so the sheet's tests read the same
    // as before the number was shared (#73). The view binds `number` directly.
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
    ///
    /// **The first state is the crossing** (SPEC §6.5): where saving would reach a goal
    /// nothing else in scope reaches yet, that is the line. It can only ever take over
    /// from Beats, First entry or the hint — a weight at or past an unreached goal is
    /// past your best by construction — and it has no opposite: lowering the entry that
    /// was reaching a goal is just the ordinary line, the derivation quietly un-reaching.
    var verdict: Verdict? {
        guard stage == .weight, let reps else { return nil }
        if let goal, let weight, goal.isCrossed(byReps: reps, weight: weight) {
            return .goal("Reaches your goal of \(goal.text)")
        }
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
    var canSave: Bool { canAdvance && (weight ?? 0) > 0 && caption.resolves }

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
        // Nothing left to re-seed for the machine already in scope.
        guard caption.select(machine) else { return }
        reseed()
    }

    /// `New machine here`: the gym is implied by the section the row sits in, so there is
    /// no gym picker and no second decision — the machine is created and **the sheet
    /// resolves to it** (SPEC §6.4).
    ///
    /// `name` is the optional one-field alert's answer, `nil` where you skipped it. It is
    /// **always asked**, because you cannot know at creation time whether a second
    /// machine is coming.
    func createMachine(at gym: Gym, named name: String?) {
        guard caption.createMachine(at: gym, named: name) else { return }
        reseed()
    }

    /// The near-name warning `New machine here` puts first — always `nil` here, since
    /// **strength machines get no near-name check** (SPEC §7.5); held so both sheets
    /// answer the same question through the one caption.
    func nearModel(named name: String?, at gym: Gym) -> ErgModelMatch? {
        caption.nearModel(named: name, at: gym)
    }

    /// `New gym…` came back with one. The picker gains its section — **and only its
    /// section**: the machine you are standing at is still the always-asked decision
    /// `New machine here` puts to you (SPEC §6.4).
    func gymCreated(_ gym: Gym) {
        caption.gymCreated(gym)
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
            // **Logging at an archived gym un-archives it** and makes it current
            // (SPEC §7.4). An *edit* does not do this — correcting a three-week-old
            // entry from your couch is not a visit.
            caption.logged()
        }
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        onSave()
    }
}
