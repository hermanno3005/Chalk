import Foundation

/// Which of the five zones a heart rate falls in, 1…5, **with a heart rate exactly on a
/// boundary in the upper zone** (SPEC §13.3).
///
/// The seam `ZoneLine` reads the zones through, so the derivation never needs to know
/// where they are held. `HeartRateZones` is the one conformer in the app.
protocol ZoneMembership {
    func zone(of heartRate: Int) -> Int
}

/// The zone line for one zone on one scope at one incline, derived from its entries and
/// never stored (SPEC §13.4, ADR-0006).
///
/// A plain struct over `[Entry]` — no `ModelContainer`, no fetch, no SwiftData beyond
/// the `Entry` type itself, nothing cached (ADR-0002). **Scoping is the caller's job**,
/// as it is for `RepMaxCurve`: every entry for a transferable erg, one machine's entries
/// for a gym-bound one. Hints never enter it.
struct ZoneLine {

    /// How many visits a point's window holds.
    static let window = 10

    /// The five zones, Z1 to Z5.
    static let zones = 1...5

    /// The end of the fixed duration axis, 20:00, in seconds. Entries longer than this
    /// are stored but get no point: each duration stands alone, so they move none.
    static let axisEnd = 1200

    /// One duration you have done in this zone: the mean of its window.
    struct Point: Equatable {
        /// Whole seconds, exactly as typed.
        let duration: Int
        /// The window's mean intensity, rounded to the unit's step.
        let intensity: Double
        /// The window's mean average heart rate, in whole bpm.
        let averageHeartRate: Int
        /// How many entries the window holds — the readout's `12 entries ›`, and the
        /// rows above the history sheet's divider.
        let entryCount: Int
    }

    /// The line's points in duration order. Empty for a zone you have never landed in,
    /// and when zones are not set.
    let points: [Point]

    /// This zone's entries at this incline that are **over 20:00**, from all time, newest
    /// first — not drawn, but behind the dimmed `2 entries over 20:00 ›` caption and the
    /// flat list it opens. Empty when there is no caption to show.
    let entriesOverTheAxis: [Entry]

    /// Each duration's window cut-off: the start of the oldest visit in it.
    private let cutOffs: [Int: Date]

    init(
        entries: [Entry],
        zones: (any ZoneMembership)?,
        unit: ErgUnit,
        zone: Int,
        incline: Double,
        calendar: Calendar = .current
    ) {
        guard let zones else {
            points = []
            cutOffs = [:]
            entriesOverTheAxis = []
            return
        }
        // Membership is the average heart rate's alone; peak is never read. Incline is a
        // dimension of the line on a speed erg, compared in its half-percent steps, and
        // not read at all on any other.
        let members = entries.filter {
            $0.isAnInterval
                && zones.zone(of: $0.averageHeartRate) == zone
                && (unit != .speed || Self.inclineSteps($0.incline) == Self.inclineSteps(incline))
        }
        let onTheAxis = members.filter { $0.duration <= Self.axisEnd }
        entriesOverTheAxis = members
            .filter { $0.duration > Self.axisEnd }
            .sorted { $0.date > $1.date }

        var points: [Point] = []
        var cutOffs: [Int: Date] = [:]
        for (duration, all) in Dictionary(grouping: onTheAxis, by: \.duration).sorted(by: { $0.key < $1.key }) {
            // A visit is a calendar day, so the window is counted in days, not entries,
            // and only a new day can push the oldest out.
            let visits = Set(all.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
            let cutOff = visits.prefix(Self.window).last!
            let window = all.filter { $0.date >= cutOff }

            cutOffs[duration] = cutOff
            points.append(Point(
                duration: duration,
                intensity: Self.mean(of: window.map(\.intensity), in: unit),
                averageHeartRate: Int((Double(window.map(\.averageHeartRate).reduce(0, +)) / Double(window.count)).rounded()),
                entryCount: window.count
            ))
        }
        self.points = points
        self.cutOffs = cutOffs
    }

    /// Where the window at `duration` begins: the start of the oldest visit in it.
    /// Entries dated before it are outside the point — the history sheet draws its
    /// `Older — not in the line` divider there. Nil where the line has no such point.
    func cutOff(at duration: Int) -> Date? {
        cutOffs[duration]
    }

    /// Every zone's line, Z1 to Z5, at one incline, from the same scoped entries — what the
    /// zone buttons dim by and the no-line quotes read. Every line is empty without zones.
    static func lines(
        entries: [Entry],
        zones: (any ZoneMembership)?,
        unit: ErgUnit,
        incline: Double,
        calendar: Calendar = .current
    ) -> [Int: ZoneLine] {
        Dictionary(uniqueKeysWithValues: Self.zones.map { zone in
            (zone, ZoneLine(entries: entries, zones: zones, unit: unit, zone: zone, incline: incline, calendar: calendar))
        })
    }

    /// An incline as a whole number of the log's 0.5 % steps, so two inclines compare as
    /// the values you could set rather than their binary approximations.
    private static func inclineSteps(_ incline: Double) -> Int {
        Int((incline * 2).rounded())
    }

    /// The unit's own mean, rounded to its step, nearest: speed, watts and level as they
    /// are; a split through `1/split³` and back, so it averages as the power it stands for.
    private static func mean(of values: [Double], in unit: ErgUnit) -> Double {
        let count = Double(values.count)
        let mean = switch unit {
        case .split: 1 / cbrt(values.map { 1 / ($0 * $0 * $0) }.reduce(0, +) / count)
        case .speed, .watts, .level: values.reduce(0, +) / count
        }
        return unit.rounded(mean)
    }
}
