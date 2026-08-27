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

    enum Stage {
        case reps, weight
    }

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

    /// Steppers for nudges, keypad for jumps — the same pair on both stages (SPEC §6.2).
    enum InputMode {
        case steppers, keypad
    }

    /// A keypad press. `decimal` is dead on the reps stage.
    enum Key: Equatable {
        case digit(Int)
        case decimal
        case delete
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

    private(set) var stage: Stage = .reps
    private(set) var mode: InputMode = .steppers
    private(set) var reps: Int?
    private(set) var weight: Double?

    /// The gyms made from this sheet's own `New gym…`, which hold no machine for this
    /// exercise yet and still need a section to make one in.
    @ObservationIgnored private var addedHere: [Gym] = []

    /// What the keypad has typed on the stage in view. Held as text, not a number, so
    /// a half-typed `62.` shows what your thumb typed rather than snapping to `62`.
    /// Cleared whenever the keypad opens or closes.
    private var typed = ""

    /// What the number said when the keypad opened over it. **A stray tap is not an
    /// edit**: closing the keypad without typing anything puts the seed back rather
    /// than costing you the two-tap log (SPEC §6.3).
    private var beforeKeypad: (reps: Int?, weight: Double?)?

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

    /// The grid weight steps onto, in kilograms. **Global and hard-coded** — not
    /// per-exercise, not per-machine, not a setting, and not a schema field (SPEC §6.2).
    private static let weightGrid = 2.5

    /// The cold-start rep count (SPEC §6.3). There is no cold-start weight: the app
    /// never guesses a load it cannot back up.
    private static let defaultReps = 5

    /// The keypad's ceiling. Not a validation rule — there is no upper bound on a lift
    /// (SPEC §6.7) — just the point past which a thumb is holding a key down by mistake.
    private static let maxTypedLength = 6

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
            reps = editing.reps
            weight = editing.weight
        } else {
            // **Reps seed from your most recent entry on any machine** — rep counts
            // transfer between machines in a way loads do not (SPEC §6.3).
            reps = LastEntry.latest(in: entriesOnAnyMachine)?.reps ?? Self.defaultReps
            // **The weight only from this exact machine**, so no number you have never
            // lifted *there* is ever one tap from Save.
            weight = LastEntry.latest(in: entries)?.weight
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
        hint = MachineHint.lookUp(exercise, scopedTo: machine)
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

    /// The giant number, on whichever stage is in view. Empty while the value is blank —
    /// an absence, not a zero.
    var numberText: String {
        if mode == .keypad {
            return typed.replacingOccurrences(of: ".", with: WeightText.decimalSeparator)
        }
        switch stage {
        case .reps: return reps.map(String.init) ?? ""
        case .weight: return weight.map(\.kilogramsText) ?? ""
        }
    }

    /// The quiet unit beside the number.
    var unitText: String {
        switch stage {
        case .reps: return reps == 1 ? "rep" : "reps"
        case .weight: return "kg"
        }
    }

    /// The stage-two header: the earlier answer, always visible and one tap from being
    /// corrected without cancelling (SPEC §6.1).
    var repsLabel: String {
        guard let reps else { return "reps" }
        return reps == 1 ? "1 rep" : "\(reps) reps"
    }

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
                return .hint("No history here — \(hint.text)")
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

    var canAdvance: Bool { (reps ?? 0) >= 1 }

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
        let label = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let machine = Machine(
            label: (label?.isEmpty == false) ? label : nil,
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
        weight = LastEntry.latest(in: entries)?.weight
        // Only where that weight is the number on screen; on stage one the seed simply
        // waits for `advance()`.
        if stage == .weight { openWeightStage() }
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

    // MARK: - Staging

    func advance() {
        guard canAdvance else { return }
        stage = .weight
        openWeightStage()
    }

    /// The weight stage, opened over whatever the seed left. **A weight nobody has
    /// proven on this machine opens blank with the keypad already up** — not a new
    /// control, just the mode the sheet already has, chosen at the one moment it is
    /// obviously right (SPEC §6.3). Reached twice: arriving from stage one, and
    /// correcting the machine while already here.
    private func openWeightStage() {
        typed = ""
        beforeKeypad = nil
        mode = weight == nil ? .keypad : .steppers
    }

    func backToReps() {
        stage = .reps
        typed = ""
        beforeKeypad = nil
        mode = .steppers
    }

    // MARK: - The two input modes

    /// Tapping the giant number swaps the steppers for the keypad, and back (SPEC §6.2).
    /// The keypad always opens empty: it is there for jumps, and a jump starts from
    /// scratch rather than editing the digits of the number underneath.
    func tapNumber() {
        if mode == .keypad {
            // Leaving keeps what was typed — or, if nothing was, puts back the number
            // the keypad opened over.
            if typed.isEmpty, let beforeKeypad {
                reps = beforeKeypad.reps
                weight = beforeKeypad.weight
            }
            beforeKeypad = nil
            mode = .steppers
        } else {
            // Opening blanks the value, which is what makes 5 → 12 two taps rather
            // than a correction of the digits underneath.
            beforeKeypad = (reps, weight)
            mode = .keypad
        }
        typed = ""
        if mode == .keypad { applyTyped() }
    }

    /// A keypad press. The typed value flows into reps/weight as you type, so the
    /// verdict stays live (SPEC §6.2).
    func type(_ key: Key) {
        mode = .keypad
        switch key {
        case .digit(let digit):
            guard typed.count < Self.maxTypedLength else { return }
            // A lone leading zero is a placeholder, not a digit of the number.
            typed = typed == "0" ? String(digit) : typed + String(digit)
        case .decimal:
            // Dead on the reps stage — reps are whole (SPEC §6.2).
            guard stage == .weight, !typed.contains(".") else { return }
            guard typed.count < Self.maxTypedLength else { return }
            typed = typed.isEmpty ? "0." : typed + "."
        case .delete:
            guard !typed.isEmpty else { return }
            typed.removeLast()
        }
        applyTyped()
    }

    /// One stepper tap: **±1 rep, ±2.5 kg**. Tap only — no hold-to-repeat and no
    /// acceleration, because the correction for an overshoot overshoots back (SPEC §6.2).
    func step(_ direction: Int) {
        switch stage {
        case .reps:
            reps = max(1, (reps ?? 0) + direction)
        case .weight:
            weight = Self.snapped(weight ?? 0, direction)
        }
    }

    /// **The next multiple of 2.5 in the direction tapped — not an addition** (SPEC §6.2).
    /// From a keypad-typed 57: `+` → 57.5 → 60; `−` → 55 → 52.5. On-grid values are
    /// indistinguishable from plain arithmetic, which is the common case.
    private static func snapped(_ weight: Double, _ direction: Int) -> Double {
        let steps = weight / weightGrid
        let nearest = steps.rounded()
        let onGrid = abs(steps - nearest) < 1e-9
        let target = onGrid
            ? nearest + Double(direction < 0 ? -1 : 1)
            : (direction < 0 ? steps.rounded(.down) : steps.rounded(.up))
        // Never negative (SPEC §6.2). 0 kg is displayable but not savable.
        return max(0, target * weightGrid)
    }

    private func applyTyped() {
        switch stage {
        case .reps: reps = typed.isEmpty ? nil : Int(typed)
        case .weight: weight = typed.isEmpty ? nil : Double(typed)
        }
    }

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
