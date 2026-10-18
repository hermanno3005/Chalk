import Foundation

/// One endurance number typed on the keypad — **the formats and clamps the lap-list grid
/// and the endurance goal sheet share** (SPEC §13.7, §13.10), so typing is the same
/// everywhere and nothing is copied.
///
/// **An input, not a meaning**, as `TwoStageNumber` is: it knows how a duration, an
/// intensity in each unit, an incline and a heart rate are typed, and nothing about
/// entries, rows, validation or saving.
///
/// - **Times fill from the right**, as on a microwave: `6`, `60`, `600` → `6:00`, and
///   `h:mm:ss` from an hour. Typed to the second and never snapped.
/// - **A split takes a tenth after the decimal key** (`1:47.5`).
/// - **The decimal key is dead** on a duration, watts, a level and a heart rate.
/// - **A speed takes 0.1 km/h**: a second digit after the decimal is refused (`15.05`).
/// - **An incline takes 0.5 % steps**: only `0` or `5` after the decimal, and it can
///   never go below 0 — there is no minus key. 0 % is a value.
///
/// **Typing replaces the seed**: the first key on a value blanks it. **A stray tap is not
/// an edit**: settling with nothing typed puts the seed back (SPEC §6.3's rule).
struct EnduranceInput: Equatable {

    /// What a key press did.
    enum Outcome: Equatable {
        /// The key does nothing here — a dead decimal, an off-step digit, a full field.
        /// Nothing changes, and the seed is not blanked.
        case refused
        case typed
        /// The value cannot take another key, so the caller may move on by itself: a
        /// heart rate's last digit, a speed's tenth (SPEC §13.7).
        case complete
    }

    let field: EnduranceField
    let unit: ErgUnit
    /// The number, or nil while blank — blank is a real state while typing.
    private(set) var value: Double?

    /// The keys typed over the value, or nil while not typing. Held as text so a
    /// half-typed `15.` shows what your thumb typed.
    private var typed: String?
    /// What the value was when typing began, put back if nothing is typed.
    private var seed: Double?

    init(_ field: EnduranceField, unit: ErgUnit, value: Double? = nil) {
        self.field = field
        self.unit = unit
        self.value = value
    }

    /// What the cell shows: the keys as typed, or the value written in its format.
    var text: String {
        if let typed { return display(typed) }
        return value.map { EnduranceText.cell($0, field, unit) } ?? ""
    }

    /// Whether keys are being typed over the value right now. A value mid-typing is not
    /// judged yet: `1` on the way to `164` is not a heart rate.
    var isTyping: Bool { typed != nil }

    /// Whether the keypad's decimal key is live here.
    var takesDecimal: Bool {
        switch field {
        case .incline: true
        case .intensity: unit == .speed || unit == .split
        case .duration, .averageHeartRate, .peakHeartRate: false
        }
    }

    /// One key.
    @discardableResult
    mutating func type(_ key: TwoStageNumber.Key) -> Outcome {
        var text = typed ?? ""
        switch key {
        case .digit(let digit):
            if let dot = text.firstIndex(of: ".") {
                // One digit after the decimal, and an off-step one is refused.
                guard text[text.index(after: dot)...].isEmpty else { return .refused }
                if field == .incline, digit != 0, digit != 5 { return .refused }
                text += String(digit)
            } else {
                guard text.count < maxDigits else { return .refused }
                // A lone leading zero is a placeholder, not a digit of the number.
                text = text == "0" ? String(digit) : text + String(digit)
            }
        case .decimal:
            guard takesDecimal, !text.contains(".") else { return .refused }
            text = text.isEmpty ? "0." : text + "."
        case .delete:
            // On a value not being typed over, delete is the first key: it blanks it.
            if typed != nil {
                guard !text.isEmpty else { return .refused }
                text.removeLast()
            }
        }
        if typed == nil { seed = value }
        typed = text
        value = parse(text)
        return isComplete(text) ? .complete : .typed
    }

    /// Stops typing over the value. **Nothing typed puts the seed back.**
    mutating func settle() {
        if typed?.isEmpty == true { value = seed }
        typed = nil
        seed = nil
    }

    // MARK: - Formats

    /// Whether this field is typed as a clock, filling from the right.
    private var isClock: Bool {
        field == .duration || (field == .intensity && unit == .split)
    }

    /// The most digits before the decimal: past it, a thumb is holding a key down.
    private var maxDigits: Int {
        switch field {
        case .duration: 6
        case .incline: 2
        case .averageHeartRate, .peakHeartRate: 3
        case .intensity:
            switch unit {
            case .speed, .level: 2
            case .watts, .split: 4
            }
        }
    }

    private func parse(_ text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        guard isClock else { return Double(text) }
        let (digits, tenth) = clockParts(text)
        let seconds = Double(digits.suffix(2)) ?? 0
        let minutes = Double(digits.dropLast(2).suffix(2)) ?? 0
        let hours = Double(digits.dropLast(4)) ?? 0
        return hours * 3600 + minutes * 60 + seconds + (Double(tenth) ?? 0) / 10
    }

    private func display(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        guard isClock else {
            return text.replacingOccurrences(of: ".", with: WeightText.decimalSeparator)
        }
        let (digits, tenth) = clockParts(text)
        let padded = digits.count < 2 ? String(repeating: "0", count: 2 - digits.count) + digits : digits
        let seconds = padded.suffix(2)
        let rest = padded.dropLast(2)
        var clock: String
        if rest.count > 2 {
            clock = "\(rest.dropLast(2)):\(rest.suffix(2)):\(seconds)"
        } else {
            clock = "\(rest.isEmpty ? "0" : String(rest)):\(seconds)"
        }
        if text.contains(".") { clock += WeightText.decimalSeparator + tenth }
        return clock
    }

    /// A clock's digits before the decimal, and the tenth after it.
    private func clockParts(_ text: String) -> (digits: String, tenth: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "")
    }

    private func isComplete(_ text: String) -> Bool {
        switch field {
        case .averageHeartRate, .peakHeartRate:
            // Three digits, or two where no third could follow: every heart rate from
            // 40 to 99 is two digits, and none from 100 to 230 starts with 4–9.
            guard let first = text.first?.wholeNumberValue else { return false }
            return text.count == 3 || (text.count == 2 && first >= 4)
        case .intensity where unit == .speed:
            return text.contains(".") && !text.hasSuffix(".")
        default:
            return false
        }
    }
}
