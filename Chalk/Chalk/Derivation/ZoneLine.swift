import Foundation

/// The zone line for one zone on one scope at one incline, derived from its entries and
/// never stored (SPEC §13.4, ADR-0006).
///
/// A plain struct over `[Entry]` — no `ModelContainer`, no fetch, no SwiftData beyond
/// the `Entry` type itself, nothing cached (ADR-0002). **Scoping is the caller's job**,
/// as it is for `RepMaxCurve`: every entry for a transferable erg, one machine's entries
/// for a gym-bound one. Hints never enter it.
///
/// The zones are passed in, never read here: `nil` — not yet set — gives no line.
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
        /// How many entries the window holds — the `Entries 12 ›` row, and the
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

    /// Every duration's point, **over 20:00 too** — those are never drawn, but a goal can
    /// name one (SPEC §13.10), and it is read by the same window and mean as the rest.
    private let pointsByDuration: [Int: Point]

    /// Every entry on this line — this zone, this incline — at any duration, from all
    /// time: what `entries(at:)` reads.
    private let members: [Entry]

    init(
        entries: [Entry],
        zones: HeartRateZones?,
        unit: ErgUnit,
        zone: Int,
        incline: Double,
        calendar: Calendar = .current
    ) {
        guard let zones else {
            points = []
            cutOffs = [:]
            pointsByDuration = [:]
            entriesOverTheAxis = []
            members = []
            return
        }
        // Membership is the average heart rate's alone; peak is never read. Incline is a
        // dimension of the line on a speed erg, compared in its half-percent steps, and
        // not read at all on any other.
        let members = entries.filter {
            $0.isAnInterval
                && zones.zone(of: $0.averageHeartRate) == zone
                && (!unit.hasIncline || ErgUnit.inclineSteps($0.incline) == ErgUnit.inclineSteps(incline))
        }
        self.members = members
        entriesOverTheAxis = members
            .filter { $0.duration > Self.axisEnd }
            .sorted { $0.date > $1.date }

        var pointsByDuration: [Int: Point] = [:]
        var cutOffs: [Int: Date] = [:]
        for (duration, all) in Dictionary(grouping: members, by: \.duration) {
            // A visit is a calendar day, so the window is counted in days, not entries,
            // and only a new day can push the oldest out.
            let visits = Set(all.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
            let cutOff = visits.prefix(Self.window).last!
            let window = all.filter { $0.date >= cutOff }

            if duration <= Self.axisEnd { cutOffs[duration] = cutOff }
            pointsByDuration[duration] = Point(
                duration: duration,
                intensity: Self.mean(of: window.map(\.intensity), in: unit),
                averageHeartRate: Int((Double(window.map(\.averageHeartRate).reduce(0, +)) / Double(window.count)).rounded()),
                entryCount: window.count
            )
        }
        self.points = pointsByDuration.values
            .filter { $0.duration <= Self.axisEnd }
            .sorted { $0.duration < $1.duration }
        self.cutOffs = cutOffs
        self.pointsByDuration = pointsByDuration
    }

    /// The point at exactly `duration`, **drawn or not**: past 20:00 it is off the line
    /// but still a point, by the same window and mean, so a goal there reads against it
    /// (SPEC §13.10). Nil where this zone holds nothing at that duration.
    func point(at duration: Int) -> Point? {
        pointsByDuration[duration]
    }

    /// Where the window at `duration` begins: the start of the oldest visit in it.
    /// Entries dated before it are outside the point — the history sheet draws its
    /// `Older — not in the line` divider there. Nil where the line has no such point.
    func cutOff(at duration: Int) -> Date? {
        cutOffs[duration]
    }

    /// Every entry at `duration` on this line — this zone, this incline — **from all
    /// time**, newest first: everything that could make the point, which is what its
    /// history sheet lists (SPEC §13.9). Those dated before `cutOff(at:)` are outside the
    /// window, under the sheet's divider. Empty where nothing was done at that duration.
    func entries(at duration: Int) -> [Entry] {
        members.filter { $0.duration == duration }.sorted { $0.date > $1.date }
    }

    /// Every zone's line, Z1 to Z5, at one incline, from the same scoped entries — what the
    /// zone tabs dim by and the no-line quotes read. Every line is empty without zones.
    static func lines(
        entries: [Entry],
        zones: HeartRateZones?,
        unit: ErgUnit,
        incline: Double,
        calendar: Calendar = .current
    ) -> [Int: ZoneLine] {
        Dictionary(uniqueKeysWithValues: Self.zones.map { zone in
            (zone, ZoneLine(entries: entries, zones: zones, unit: unit, zone: zone, incline: incline, calendar: calendar))
        })
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
