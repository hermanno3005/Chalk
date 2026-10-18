import Foundation

/// The kind of number an erg's intensity is written in. A unit is a kind of number,
/// never a brand, and Chalk converts nothing between units.
///
/// Stored on `Exercise.unit` as its `rawValue`, as `kind` is, so the store stays
/// CloudKit-shaped and readable in `sqlite3` (ADR-0001). A lift has no unit.
enum ErgUnit: String, Codable, CaseIterable {
    /// km/h, in tenths. Its pace in min/km is shown beside it, for display only.
    case speed
    /// Whole watts.
    case watts
    /// Seconds per 500 m, in tenths. Lower is harder.
    case split
    /// The console's own scale, in whole levels.
    case level

    /// The smallest difference this unit can hold: what the log refuses to go between,
    /// and what every derived number is rounded to.
    var step: Double {
        switch self {
        case .speed, .split: 0.1
        case .watts, .level: 1
        }
    }

    /// `value` as a whole number of steps, the **only** way a derived intensity is ever
    /// compared (ADR-0008).
    ///
    /// 0.1 km/h is not exact in binary floating point the way 2.5 kg is: a mean of nine
    /// `15.1`s comes out a hair above `15.1`, and thirteen a hair below. In steps both
    /// are 151, so reached, the gap and the ring compare the number you could set
    /// rather than its binary approximation.
    func steps(_ value: Double) -> Int {
        Int((value / step).rounded())
    }

    /// `value` rounded to the nearest step — a number you could set on the machine.
    /// Divided back by the steps per whole rather than multiplied by the step, because
    /// `151 * 0.1` is not `15.1` but `151 / 10` is.
    func rounded(_ value: Double) -> Double {
        Double(steps(value)) / (1 / step).rounded()
    }

    // MARK: - Harder

    /// `1`, or `-1` on a split, where lower is harder: multiplied in, an intensity reads
    /// harder-is-more on every unit. **The one place a split's direction lives.**
    var hardnessSign: Double {
        self == .split ? -1 : 1
    }

    /// `value` in whole steps, signed so that harder is more on every unit — the steps to
    /// subtract when a goal's gap or ring asks how much harder one number is than another.
    func hardness(_ value: Double) -> Int {
        steps(value) * Int(hardnessSign)
    }
}

// MARK: - Incline

extension ErgUnit {

    /// Whether this unit's intervals carry an incline — a speed erg's only. On every other
    /// unit an entry stores 0 and nothing reads it, and a goal stores none.
    var hasIncline: Bool {
        self == .speed
    }

    /// The log's incline step: an incline is set in half percents.
    static let inclineStep = 0.5

    /// `incline` as a whole number of 0.5 % steps, so two inclines compare as the values
    /// you could set rather than their binary approximations.
    static func inclineSteps(_ incline: Double) -> Int {
        Int((incline / inclineStep).rounded())
    }

    /// `incline` rounded to the nearest 0.5 % — an incline you could set. Multiplied back
    /// by the step, which 0.5 is exact in binary.
    static func roundedIncline(_ incline: Double) -> Double {
        Double(inclineSteps(incline)) * inclineStep
    }
}
