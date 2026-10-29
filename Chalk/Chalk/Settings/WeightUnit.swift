import Foundation

/// The **weight unit** (SPEC §15.2, ADR-0009): the scale every strength weight and
/// strength goal is written on, app-wide. **Nothing converts at read time**: a stored
/// weight is a plain number on the scale chosen now, and this only says which one.
///
/// One `UserDefaults` key holding the raw value, held per device beside the store as the
/// zones are. The key is held here so the views that read it through `@AppStorage` and
/// the models that read it through `UserDefaults` cannot drift. It starts unset, which onboarding reads as *not yet chosen*, and
/// **reads as kg while unset**, because every number an install from before units wrote
/// is kg (SPEC §2).
enum WeightUnit: String, CaseIterable, Sendable {
    case kg, lb

    static let key = "weightUnit"

    /// The unit this device holds, or kg while none is stored.
    init(defaults: UserDefaults) {
        self = Self.stored(in: defaults) ?? .kg
    }

    /// The unit this device holds, or `nil` while none is stored.
    static func stored(in defaults: UserDefaults) -> WeightUnit? {
        defaults.string(forKey: key).flatMap(WeightUnit.init(rawValue:))
    }

    /// Writes this unit over whatever this device held.
    func save(to defaults: UserDefaults) {
        defaults.set(rawValue, forKey: Self.key)
    }

    /// The symbol written after a weight: `kg` or `lb`.
    var symbol: String { rawValue }

    /// What VoiceOver says for it: `kilograms` or `pounds`.
    var spokenName: String {
        switch self {
        case .kg: "kilograms"
        case .lb: "pounds"
        }
    }

    /// A weight as VoiceOver says it: `102.5 pounds`, `1 kilogram`.
    func spokenText(_ weight: Double) -> String {
        let name = weight == 1 ? String(spokenName.dropLast()) : spokenName
        return "\(weight.weightText) \(name)"
    }

    /// The grid the steppers snap to: **2.5 kg or 5 lb**, the smallest change a pair of
    /// the scale's smallest standard plates makes. The unit alone picks it, and it is not
    /// a setting (SPEC §6.2, §15.2).
    var grid: Double {
        switch self {
        case .kg: 2.5
        case .lb: 5
        }
    }

    /// A weight with its symbol: `52.5 kg`, `225 lb`.
    func text(_ weight: Double) -> String {
        "\(weight.weightText) \(symbol)"
    }

    /// `weight` on this scale, **converted** onto `unit`'s and rounded to its convert grid
    /// (SPEC §15.2, ADR-0009): `100 kg` is `220 lb`, and `225 lb` is `102 kg`.
    func converted(_ weight: Double, to unit: WeightUnit) -> Double {
        unit.onConvertGrid(weight * kilograms / unit.kilograms)
    }

    /// `weight` rounded to the grid a convert writes on: **0.5 kg or 1 lb**, nearest step,
    /// ties up. **Never the stepper grid**, so a converted `220 lb` waits between steps
    /// until the next `+` snaps it to `225` (SPEC §6.2).
    func onConvertGrid(_ weight: Double) -> Double {
        // Every weight is positive, so ties away from zero are ties up. Whole steps are
        // divided back, never multiplied by a fraction, so `n / 2` is exact.
        (weight * stepsPerUnit).rounded() / stepsPerUnit
    }

    /// One of this unit in kilograms: a pound is exactly 0.45359237 kg, by definition.
    private var kilograms: Double {
        switch self {
        case .kg: 1
        case .lb: 0.45359237
        }
    }

    /// How many convert-grid steps make one of this unit.
    private var stepsPerUnit: Double {
        switch self {
        case .kg: 2
        case .lb: 1
        }
    }
}
