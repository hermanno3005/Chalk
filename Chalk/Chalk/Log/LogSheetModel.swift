import Foundation
import Observation
import SwiftData

/// The two-stage log sheet's state: reps, then weight, one giant number at a time
/// (SPEC §6.1–6.3, §6.5, §6.7).
///
/// **The sheet never resolves a machine — its caller does** (§6.4): it is handed one, it
/// writes the entry onto it, and every number it shows is derived from that machine's
/// entries alone. The tappable caption that lets you correct it is #28, and its hint
/// verdict #29; both land as a line on a sheet that already knows its machine, not as a
/// third stage.
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
    /// carry; **never nil for a gym-bound one**, where an entry with no machine is not
    /// producible by any UI path (SPEC §3, invariant 4) and `canSave` refuses one.
    let machine: Machine?

    /// The entry being corrected, or nil for a new one. **The only difference between
    /// the two presentations** — everything below this line is the same sheet.
    @ObservationIgnored private let editing: Entry?

    private(set) var stage: Stage = .reps
    private(set) var mode: InputMode = .steppers
    private(set) var reps: Int?
    private(set) var weight: Double?

    /// What the keypad has typed on the stage in view. Held as text, not a number, so
    /// a half-typed `62.` shows what your thumb typed rather than snapping to `62`.
    /// Cleared whenever the keypad opens or closes.
    private var typed = ""

    /// What the number said when the keypad opened over it. **A stray tap is not an
    /// edit**: closing the keypad without typing anything puts the seed back rather
    /// than costing you the two-tap log (SPEC §6.3).
    private var beforeKeypad: (reps: Int?, weight: Double?)?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let onSave: () -> Void
    /// The entries the verdict is derived against — read once, at open. They are the
    /// picture behind the sheet, and the sheet closes on the write that would change it.
    @ObservationIgnored private let entries: [Entry]

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
        onSave: @escaping () -> Void = {}
    ) {
        self.exercise = exercise
        self.machine = machine
        self.editing = editing
        self.context = context
        self.onSave = onSave
        // The entry being edited is not part of its own verdict: the line says how this
        // lift stands against the rest of your history, and an entry compared with
        // itself says nothing (SPEC §6.5).
        // The scope the screen behind the sheet is in (SPEC §5.3): one machine's
        // entries for a gym-bound exercise, so neither the seed nor the verdict can
        // quote a weight proven somewhere else.
        self.entries = MachineScope.entries(of: exercise, on: machine)
            .filter { $0 !== editing }

        if let editing {
            // Seeded from *that* entry — the numbers you tapped, ready to be corrected.
            reps = editing.reps
            weight = editing.weight
        } else {
            // Seeded from your most recent entry, so the common log is two taps
            // (SPEC §6.3). For a free-weight exercise the weight seed is the same entry
            // as the rep seed; scoping to one machine's entries is what splits them.
            let latest = LastEntry.latest(in: entries)
            reps = latest?.reps ?? Self.defaultReps
            weight = latest?.weight
        }
    }

    // MARK: - What the sheet shows

    /// The day the entry being edited was logged — **and the sheet's only tell that it
    /// is an edit**, which is as much difference as §6.6 asks for. **Shown, not editable** — the sheet
    /// says which lift you are correcting, and offers no way to move it.
    var dateLabel: String? {
        editing.flatMap(LastEntry.init)?.day()
    }

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
    /// The fifth state, the machine hint, arrives with the caption (#29).
    var verdict: String? {
        guard stage == .weight, let reps else { return nil }
        guard let best = RepMaxCurve.best(atLeast: reps, in: entries) else {
            return "First entry at \(reps) reps"
        }
        // A blank weight compares as the nothing it is, which reads as "below".
        let weight = weight ?? 0
        if weight > best {
            return "Beats your \(reps)-rep best by \((weight - best).kilogramsText) kg"
        }
        if weight == best {
            return "Matches your \(reps)-rep best"
        }
        return "Your \(reps)-rep best is \(best.kilogramsText) kg"
    }

    var canAdvance: Bool { (reps ?? 0) >= 1 }

    /// `reps >= 1` and `weight > 0` (SPEC §6.7). No upper bound and no outlier
    /// confirmation — a typo is corrected, not prevented.
    /// **A gym-bound exercise must resolve a machine** (SPEC §3, invariant 4): with no
    /// machine there is nothing to write the entry onto, and an unscoped entry pollutes
    /// the derivation forever. The sheet is never opened in that state — the row that
    /// creates a machine mid-log is #28 — and this is the guard that keeps it so.
    var canSave: Bool { canAdvance && (weight ?? 0) > 0 && (machine != nil || !exercise.isGymBound) }

    // MARK: - Staging

    func advance() {
        guard canAdvance else { return }
        stage = .weight
        typed = ""
        beforeKeypad = nil
        // The one moment the keypad is obviously right: a weight nobody has proven yet
        // is typed in from scratch, so the sheet opens the mode it already has (§6.3).
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
            }
        }
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        onSave()
    }
}
