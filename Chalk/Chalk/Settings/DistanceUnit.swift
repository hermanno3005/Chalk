import Foundation

/// The **distance unit** (SPEC §15.2, ADR-0009): the scale every speed erg's intensity and
/// speed goal is written on, app-wide, and independent of the weight unit. A speed reads
/// **km/h with its pace per km, or mph with its pace per mile**. **Nothing converts at
/// read time**: a stored speed is a plain number on the scale chosen now, and this only
/// says which one. Watts, splits and levels have no scale and never read it.
///
/// One `UserDefaults` key holding the raw value, held per device beside the store as the
/// zones and the weight unit are. The key is held here so the views that read it through
/// `@AppStorage` and the models that read it through `UserDefaults` cannot drift. It
/// starts unset, which onboarding reads as *not yet chosen*, and **reads as km while
/// unset**, because every speed an install from before units wrote is km/h (SPEC §2).
enum DistanceUnit: String, CaseIterable, Sendable {
    case km, mi

    static let key = "distanceUnit"

    /// The unit this device holds, or km while none is stored.
    init(defaults: UserDefaults) {
        self = Self.stored(in: defaults) ?? .km
    }

    /// The unit this device holds, or `nil` while none is stored.
    static func stored(in defaults: UserDefaults) -> DistanceUnit? {
        defaults.string(forKey: key).flatMap(DistanceUnit.init(rawValue:))
    }

    /// Writes this unit over whatever this device held.
    func save(to defaults: UserDefaults) {
        defaults.set(rawValue, forKey: Self.key)
    }

    /// The symbol written after a speed: `km/h` or `mph`.
    var speedSymbol: String {
        switch self {
        case .km: "km/h"
        case .mi: "mph"
        }
    }

    /// The distance a pace is per: `/km` or `/mi`. Spelled out rather than built from the
    /// raw value, which a backup stores and the screen must not depend on.
    var paceSymbol: String {
        switch self {
        case .km: "/km"
        case .mi: "/mi"
        }
    }

    /// What a restore's confirmation calls distances on this scale: `km` or `miles`.
    var name: String {
        switch self {
        case .km: "km"
        case .mi: "miles"
        }
    }
}
