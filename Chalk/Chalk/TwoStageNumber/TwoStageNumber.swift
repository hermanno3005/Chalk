import Foundation

/// The two-stage giant number: reps, then weight, one number on screen at a time
/// (SPEC §6.1–6.2). Steppers for nudges, keypad for jumps, on both stages.
///
/// **An input, not a meaning.** It knows how a rep count and a weight are entered and
/// nothing about what they are for — no entry, no machine, no verdict, no save. The log
/// sheet seeds it from your history and writes an entry from it; the goal sheet borrows
/// it whole and names a goal with it (#65).
///
/// Both numbers are optional because **blank is a real state**: a weight nobody can back
/// up opens empty rather than guessed (§6.3), and the keypad can be cleared back to
/// nothing. What a blank blocks is the caller's to say.
struct TwoStageNumber {

    enum Stage {
        case reps, weight
    }

    /// Steppers for nudges, keypad for jumps — the same pair on both stages (SPEC §6.2).
    enum Mode {
        case steppers, keypad
    }

    /// A keypad press. `decimal` is dead on the reps stage.
    enum Key: Equatable {
        case digit(Int)
        case decimal
        case delete
    }

    private(set) var stage: Stage = .reps
    private(set) var mode: Mode = .steppers
    private(set) var reps: Int?
    private(set) var weight: Double?

    /// What the keypad has typed on the stage in view. Held as text, not a number, so
    /// a half-typed `62.` shows what your thumb typed rather than snapping to `62`.
    /// Cleared whenever the keypad opens or closes.
    private var typed = ""

    /// What the number said when the keypad opened over it. **A stray tap is not an
    /// edit**: closing the keypad without typing anything puts back the number it
    /// opened over (SPEC §6.3).
    private var beforeKeypad: (reps: Int?, weight: Double?)?

    /// The grid weight steps onto, in kilograms. **Global and hard-coded** — not
    /// per-exercise, not per-machine, not a setting, and not a schema field (SPEC §6.2).
    private static let weightGrid = 2.5

    /// The keypad's ceiling. Not a validation rule — there is no upper bound on a lift
    /// (SPEC §6.7) — just the point past which a thumb is holding a key down by mistake.
    private static let maxTypedLength = 6

    /// Opens on reps, with the steppers, over whatever the caller seeded.
    init(reps: Int?, weight: Double?) {
        self.reps = reps
        self.weight = weight
    }

    // MARK: - What it shows

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

    var canAdvance: Bool { (reps ?? 0) >= 1 }

    // MARK: - Staging

    mutating func advance() {
        guard canAdvance else { return }
        stage = .weight
        openWeightStage()
    }

    mutating func backToReps() {
        stage = .reps
        typed = ""
        beforeKeypad = nil
        mode = .steppers
    }

    /// Replaces the weight from outside — the caller's seed moving under it. On the
    /// weight stage the stage reopens over the new value, exactly as arriving from reps
    /// would; on the reps stage the value simply waits for `advance()`.
    mutating func seedWeight(_ weight: Double?) {
        self.weight = weight
        if stage == .weight { openWeightStage() }
    }

    /// The weight stage, opened over whatever the seed left. **A blank weight opens with
    /// the keypad already up** — not a new control, just the mode the input already has,
    /// chosen at the one moment it is obviously right (SPEC §6.3).
    private mutating func openWeightStage() {
        typed = ""
        beforeKeypad = nil
        mode = weight == nil ? .keypad : .steppers
    }

    // MARK: - The two input modes

    /// Tapping the giant number swaps the steppers for the keypad, and back (SPEC §6.2).
    /// The keypad always opens empty: it is there for jumps, and a jump starts from
    /// scratch rather than editing the digits of the number underneath.
    mutating func tapNumber() {
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

    /// A keypad press. The typed value flows into reps/weight as you type, so whatever
    /// the caller derives from them stays live (SPEC §6.2).
    mutating func type(_ key: Key) {
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
    mutating func step(_ direction: Int) {
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
        // Never negative (SPEC §6.2). Whether 0 kg means anything is the caller's call.
        return max(0, target * weightGrid)
    }

    private mutating func applyTyped() {
        switch stage {
        case .reps: reps = typed.isEmpty ? nil : Int(typed)
        case .weight: weight = typed.isEmpty ? nil : Double(typed)
        }
    }
}
