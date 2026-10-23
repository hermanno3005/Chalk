import Foundation

/// How Chalk writes an endurance number (SPEC §13.2). Locale-aware like every number the
/// app shows: the decimal separator is wherever you are standing's.
enum EnduranceText {

    /// A duration: `m:ss`, or `h:mm:ss` from an hour.
    static func clock(_ seconds: Int) -> String {
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60, rest = seconds % 60
        return hours > 0
            ? "\(hours):\(pad(minutes)):\(pad(rest))"
            : "\(minutes):\(pad(rest))"
    }

    /// A split, in seconds per 500 m: `1:45`, or `1:45.3` with its tenth. A trailing `.0`
    /// is trimmed.
    static func split(_ seconds: Double) -> String {
        let tenths = Int((seconds * 10).rounded())
        let clock = clock(tenths / 10)
        let tenth = tenths % 10
        return tenth == 0 ? clock : "\(clock)\(WeightText.decimalSeparator)\(tenth)"
    }

    /// The intensity's number alone, as a grid cell shows it: `15.0`, `220`, `1:47.5`, `12`.
    /// **A speed keeps its tenth**, unlike a weight's trimmed zero (SPEC §13.2).
    static func intensityNumber(_ value: Double, _ unit: ErgUnit) -> String {
        switch unit {
        case .speed: value.formatted(.number.precision(.fractionLength(1)).grouping(.never))
        case .watts, .level: String(Int(value.rounded()))
        case .split: split(value)
        }
    }

    /// The intensity in its unit: `15.0 km/h (4:00 /km)`, `9.3 mph (6:27 /mi)`, `220 W`,
    /// `1:45 /500 m`, `Level 12`. `pace` adds a speed's pace beside it. Only a speed reads
    /// `distance`: the other units have no scale.
    static func intensity(_ value: Double, _ unit: ErgUnit, _ distance: DistanceUnit, pace: Bool = true) -> String {
        let number = intensityNumber(value, unit)
        switch unit {
        case .speed:
            let speed = "\(number) \(distance.speedSymbol)"
            return pace && value > 0 ? "\(speed) (\(Self.pace(value, distance)))" : speed
        case .watts: return "\(number) W"
        case .split: return "\(number) /500 m"
        case .level: return "Level \(number)"
        }
    }

    /// The intensity as a goal names it: no pace, so the line stays short, and a level
    /// written `L12` rather than `Level 12` (SPEC §13.2, §13.10).
    static func goalIntensity(_ value: Double, _ unit: ErgUnit, _ distance: DistanceUnit) -> String {
        unit == .level ? "L\(intensityNumber(value, unit))" : intensity(value, unit, distance, pace: false)
    }

    /// A speed's pace, `60 / speed` minutes per km or per mile to the whole second — the
    /// one number ever worked out from an intensity, and for display only (SPEC §13.2,
    /// §15.2): `4:00 /km`, `6:00 /mi`.
    static func pace(_ speed: Double, _ distance: DistanceUnit) -> String {
        "\(clock(Int((3600 / speed).rounded()))) \(distance.paceSymbol)"
    }

    /// An incline: `0`, `1`, `1.5`.
    static func incline(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }

    /// One cell's value, as the lap-list grid draws it.
    static func cell(_ value: Double, _ field: EnduranceField, _ unit: ErgUnit) -> String {
        switch field {
        case .duration: clock(Int(value.rounded()))
        case .intensity: intensityNumber(value, unit)
        case .incline: incline(value)
        case .averageHeartRate, .peakHeartRate: String(Int(value.rounded()))
        }
    }

    private static func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
