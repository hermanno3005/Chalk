import Foundation

// PROTOTYPE — plate breakdown (#141). Throwaway: it lives at the `prototype-plate-breakdown`
// tag, never on main.
//
// The arithmetic under a readout: the plates per side that make up a weight on a bar, from
// the weight unit's standard set, biggest first, or the nearest loadable weight below when
// the exact one is not loadable.

enum ProtoWeightUnit: String {
    case kg, lb

    /// The standard plates, biggest first. The smallest pair is the stepper grid (SPEC §6.2).
    var plates: [Double] {
        switch self {
        case .kg: [25, 20, 15, 10, 5, 2.5, 1.25]
        case .lb: [45, 35, 25, 10, 5, 2.5]
        }
    }

    /// The overflow's presets, after *No bar* and before a typed weight. lb's are on the
    /// 5 lb grid, as kg's are on the 2.5 kg one, so every weight you can step to loads.
    var barPresets: [Double] {
        switch self {
        case .kg: [20, 15, 10]
        case .lb: [45, 35, 25]
        }
    }

    var smallest: Double { plates.last! }
}

enum PlateBreakdown: Equatable {
    /// The weight is the bar alone.
    case bar
    /// Less than the bar: nothing to load.
    case belowBar
    /// The plates for one side, biggest first. `loads` is the weight they make with the bar:
    /// the weight read when `exact`, the nearest loadable weight below it when not.
    case plates([Double], loads: Double, exact: Bool)

    init(weight: Double, bar: Double, unit: ProtoWeightUnit) {
        let tolerance = 0.0001
        if abs(weight - bar) < tolerance { self = .bar; return }
        if weight < bar { self = .belowBar; return }
        let side = (weight - bar) / 2
        // Down to what the smallest plate can make.
        let loadable = (side / unit.smallest + tolerance).rounded(.down) * unit.smallest
        var left = loadable
        var plates: [Double] = []
        for plate in unit.plates {
            while left + tolerance >= plate {
                plates.append(plate)
                left -= plate
            }
        }
        let loads = bar + 2 * loadable
        // Empty `plates` with `exact` false: only the bar loads, short of the weight.
        self = .plates(plates, loads: loads, exact: abs(loads - weight) < tolerance)
    }
}

extension Double {
    /// A plate or a weight, every fraction digit it has: `1.25`, `2.5`, `20`.
    var plateText: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }
}
