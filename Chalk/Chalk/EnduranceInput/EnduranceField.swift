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
        unit == .speed ? allCases : allCases.filter { $0 != .incline }
    }

    /// The grid's column title: `Time | km/h | % | Avg | Peak`, or the unit's own word.
    func columnTitle(_ unit: ErgUnit) -> String {
        switch self {
        case .duration: "Time"
        case .incline: "%"
        case .averageHeartRate: "Avg"
        case .peakHeartRate: "Peak"
        case .intensity:
            switch unit {
            case .speed: "km/h"
            case .watts: "W"
            case .split: "/500 m"
            case .level: "Level"
            }
        }
    }

    /// The field's name in words, over the keypad: `Row 2 · Average heart rate`.
    func name(_ unit: ErgUnit) -> String {
        switch self {
        case .duration: "Duration"
        case .incline: "Incline"
        case .averageHeartRate: "Average heart rate"
        case .peakHeartRate: "Peak heart rate"
        case .intensity:
            switch unit {
            case .speed: "Speed"
            case .watts: "Power"
            case .split: "Split"
            case .level: "Level"
            }
        }
    }
}
