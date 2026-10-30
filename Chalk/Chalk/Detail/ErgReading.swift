import Foundation

/// What the erg detail screen reads off one scope (SPEC §13.8): the zone, duration and
/// incline you are looking at, every zone's line at that incline, and the readout and
/// caption they give.
///
/// A plain value over already-scoped entries, as `ZoneLine` is — **scoping is the
/// caller's job** (one machine's entries on a gym-bound erg, every entry on a
/// transferable one), and so is reading the zones, which are passed in live. Nothing is
/// cached past one read (ADR-0002): `ErgDetailModel` builds a fresh one on every
/// refresh, handing the old selection over so it survives.
struct ErgReading {

    /// Where the screen is looking: a zone, a duration on its line, and — on a speed erg —
    /// the incline the lines are read at (0 on any other erg, where it is never read).
    struct Selection: Equatable {
        var zone: Int
        /// Whole seconds. **Snapped to a duration you have done** wherever the zone has a
        /// line; kept as it was where it has none, so the no-line quotes can read the
        /// duration closest to it.
        var duration: Int
        /// In the log's 0.5 % steps.
        var incline: Double
    }

    /// The scrub readout: `15.0 km/h` with `6:00 in Z4` beside it, and the rows under the
    /// line, `Pace 4:00 /km` (or `9.3 mph`, `6:27 /mi`), `Heart rate 164 bpm` and
    /// `Entries 12 ›`. **The entry count is the uncertainty** — no ± band is drawn (SPEC
    /// §13.8).
    struct Readout: Equatable {
        /// The point's mean intensity in its unit, the large number.
        let intensity: String
        /// The point's duration and zone, beside the number.
        let aside: String
        /// A speed's pace, its own row; nil on every other unit.
        let pace: String?
        /// The point's mean average heart rate, `164 bpm`.
        let averageHeartRate: String
        /// The entries in the point, the rows of its sheet above the divider (§13.9).
        let entryCount: Int
        /// The number and its aside as VoiceOver says them: `9.3 miles per hour for 6
        /// minutes in zone 4`.
        let spoken: String
        /// The pace in words, `6 minutes 27 seconds per mile`; nil where `pace` is.
        let spokenPace: String?
        /// `164 beats per minute`.
        let spokenHeartRate: String
    }

    let unit: ErgUnit?

    /// The scale a speed is written on, read live by the caller as the zones are.
    let distanceUnit: DistanceUnit

    /// Nil until zones are set — the zones gate: no tabs, readout or line (SPEC §13.8).
    let zones: HeartRateZones?

    /// Nil while there is nothing to look at: zones not set, or no valid interval on
    /// the scope.
    private(set) var selection: Selection?

    /// Every zone's line, Z1 to Z5, on this scope at the selected incline — what the zone
    /// tabs dim by. Empty with no selection.
    private(set) var lines: [Int: ZoneLine] = [:]

    /// The incline menu's choices on a speed erg: every incline a valid interval on this
    /// scope was logged at, lowest first. Empty on every other unit, which has no menu.
    let inclines: [Double]

    /// Whether the scope holds no valid interval — §5.4's empty state: no chart, no
    /// axes, no readout.
    let isEmpty: Bool

    /// The valid intervals on the scope, kept to re-derive the lines at another incline.
    private let intervals: [Entry]

    /// - Parameter previous: the selection to keep — the screen stays where it was
    ///   across a write, a machine switch or a zones edit, as strength's scrub does
    ///   (SPEC §5.2). Nil opens on the zone, duration and incline of the scope's most
    ///   recent valid interval.
    init(
        entries: [Entry],
        zones: HeartRateZones?,
        unit: ErgUnit?,
        distanceUnit: DistanceUnit,
        keeping previous: Selection?
    ) {
        self.unit = unit
        self.distanceUnit = distanceUnit
        self.zones = zones
        intervals = entries.filter(\.isAnInterval)
        isEmpty = intervals.isEmpty
        inclines = unit?.hasIncline == true
            ? Set(intervals.map { ErgUnit.roundedIncline($0.incline) }).sorted()
            : []

        guard let zones, let unit, let latest = LastInterval.latestEntry(in: intervals) else {
            selection = nil
            return
        }
        var selection = previous ?? Selection(
            zone: zones.zone(of: latest.averageHeartRate),
            duration: latest.duration,
            incline: unit.hasIncline ? ErgUnit.roundedIncline(latest.incline) : 0
        )
        // Another machine may never have been run at this incline: read the nearest one
        // it has rather than an incline with no lines at all.
        if unit.hasIncline, !inclines.contains(selection.incline) {
            selection.incline = Self.nearest(to: selection.incline, in: inclines)
        }
        self.selection = selection
        derive()
    }

    // MARK: - What the screen shows

    /// The selected zone's line.
    var line: ZoneLine? {
        selection.flatMap { lines[$0.zone] }
    }

    /// The selected point; nil in a zone with no line here.
    var point: ZoneLine.Point? {
        guard let selection else { return nil }
        return line?.points.first { $0.duration == selection.duration }
    }

    /// Whether `zone` has a line on this scope and incline. **A zone without one is
    /// dimmed but still tappable** (SPEC §13.8).
    func hasLine(_ zone: Int) -> Bool {
        !(lines[zone]?.points.isEmpty ?? true)
    }

    var readout: Readout? {
        guard let selection, let point, let unit else { return nil }
        return Readout(
            intensity: EnduranceText.intensity(point.intensity, unit, distanceUnit, pace: false),
            aside: String(localized: "\(EnduranceText.clock(point.duration)) in Z\(selection.zone)"),
            pace: unit == .speed && point.intensity > 0 ? EnduranceText.pace(point.intensity, distanceUnit) : nil,
            averageHeartRate: String(localized: "\(point.averageHeartRate) bpm"),
            entryCount: point.entryCount,
            spoken: String(localized: "\(EnduranceText.spokenIntensity(point.intensity, unit, distanceUnit)) for \(Spoken.duration(point.duration)) in zone \(selection.zone)"),
            spokenPace: unit == .speed && point.intensity > 0 ? EnduranceText.spokenPace(point.intensity, distanceUnit) : nil,
            spokenHeartRate: Spoken.heartRate(point.averageHeartRate)
        )
    }

    /// The dimmed `2 entries over 20:00` caption under the line, nil when the selected
    /// zone, incline and scope has none. Stored but not drawn: each duration stands alone,
    /// so they move no point (SPEC §13.8).
    var overTheAxisCaption: String? {
        guard let count = line?.entriesOverTheAxis.count, count > 0 else { return nil }
        return String(localized: "\(count) entries over 20:00")
    }

    /// The caption as VoiceOver says it: `2 entries over 20 minutes`.
    var spokenOverTheAxisCaption: String? {
        guard let count = line?.entriesOverTheAxis.count, count > 0 else { return nil }
        return String(localized: "\(count) entries over \(Spoken.duration(ZoneLine.axisEnd))")
    }

    // MARK: - Selecting

    /// A zone tab. Every zone is tappable, a dimmed one too; the duration moves onto
    /// the nearest one done in the new zone, or stays put where it has no line.
    mutating func select(zone: Int) {
        guard selection != nil, ZoneLine.zones.contains(zone) else { return }
        selection?.zone = zone
        snap()
    }

    /// The scrub. **Snaps to the nearest duration you have done** — nothing between two
    /// points is a number you have held — and ignores `nil`, which is what
    /// `chartXSelection` writes on lift: that is the whole of stickiness (SPEC §5.2).
    mutating func select(duration: Int?) {
        guard let duration, selection != nil else { return }
        selection?.duration = duration
        snap()
    }

    /// The incline menu, speed ergs only: every line is re-read at the new incline.
    mutating func select(incline: Double) {
        let incline = ErgUnit.roundedIncline(incline)
        guard selection != nil, inclines.contains(incline) else { return }
        selection?.incline = incline
        derive()
    }

    // MARK: - Deriving

    private mutating func derive() {
        guard let selection, let unit else { return }
        lines = ZoneLine.lines(entries: intervals, zones: zones, unit: unit, incline: selection.incline)
        snap()
    }

    /// Puts the selected duration on the nearest point of the selected line — the shorter
    /// of two equally near. A zone with no line keeps the duration as it is.
    private mutating func snap() {
        guard let selection, let points = line?.points, !points.isEmpty else { return }
        let nearest = points.min { abs($0.duration - selection.duration) < abs($1.duration - selection.duration) }!
        self.selection?.duration = nearest.duration
    }

    /// The lower of two equally near.
    private static func nearest(to value: Double, in options: [Double]) -> Double {
        options.min { abs($0 - value) < abs($1 - value) } ?? value
    }
}
