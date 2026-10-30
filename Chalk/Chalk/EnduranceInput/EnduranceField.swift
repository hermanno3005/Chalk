import Foundation

/// One number of an endurance entry, in the order the watch's lap list reads them
/// (SPEC §13.7): `Time | km/h | % | Avg | Peak`. Incline exists on a speed erg only.
enum EnduranceField: CaseIterable, Hashable {
    case duration
    case intensity
    case incline
    case averageHeartRate
    case peakHeartRate

    /// The columns a lap-list grid draws for `unit`, in the watch's order.
    static func columns(for unit: ErgUnit) -> [EnduranceField] {
        unit.hasIncline ? allCases : allCases.filter { $0 != .incline }
    }

    /// The grid's column title: `Time | km/h | % | Avg | Peak`, a speed in the distance
    /// unit (`mph`), or the unit's own word.
    func columnTitle(_ unit: ErgUnit, _ distance: DistanceUnit) -> String {
        switch self {
        case .duration: String(localized: "Time")
        case .incline: "%"
        case .averageHeartRate: String(localized: "Avg")
        case .peakHeartRate: String(localized: "Peak")
        case .intensity:
            switch unit {
            case .speed: distance.speedSymbol
            case .watts: String(localized: "W")
            case .split: String(localized: "/500 m")
            case .level: String(localized: "Level")
            }
        }
    }

    /// The field's name in words, over the keypad: `Row 2 · Average heart rate`.
    func name(_ unit: ErgUnit) -> String {
        switch self {
        case .duration: String(localized: "Duration")
        case .incline: String(localized: "Incline")
        case .averageHeartRate: String(localized: "Average heart rate")
        case .peakHeartRate: String(localized: "Peak heart rate")
        case .intensity:
            switch unit {
            case .speed: String(localized: "Speed")
            case .watts: String(localized: "Power")
            case .split: String(localized: "Split")
            case .level: String(localized: "Level")
            }
        }
    }
}
