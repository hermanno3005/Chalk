import Foundation

/// A point on the zone line you have not held yet — a zone, a duration and an
/// intensity, plus an incline on a speed erg — judged against one scope's entries
/// (ADR-0007), as `Goal` is strength's (ADR-0004). Only the fields are stored; **reached,
/// the gap, the origin and the ring's fill are derived here each time**, so a slower
/// visit quietly un-reaches a goal and there is no stale state to repair (ADR-0002).
///
/// **The only way to build an endurance goal**: a partly filled set of fields is no goal
/// at all, and a speed goal with no incline is a partly filled set.
///
/// A plain struct over `[Entry]`, beside `ZoneLine` and read off it. **Scoping is the
/// caller's job**, exactly as it is there: every entry for a transferable erg, one
/// machine's entries for a gym-bound one. The zones and the distance unit are passed in,
/// read live.
struct EnduranceGoal: Equatable {
    let unit: ErgUnit
    /// The scale a speed goal is written on (SPEC §15.2). Read by the words only: the
    /// goal's numbers are plain numbers on whatever scale is chosen now.
    let distanceUnit: DistanceUnit
    /// 1…5 — a zone, never a bpm, so the goal follows your boundaries when they move.
    let zone: Int
    /// Whole seconds. Over 20:00 is an ordinary goal, read against a point that is never
    /// drawn.
    let duration: Int
    /// In the unit, as typed; a split as seconds per 500 m.
    let intensity: Double
    /// In the log's 0.5 % steps on a speed erg; nil on every other unit, which has no
    /// incline to hold.
    let incline: Double?
    /// When the goal was last set — the moment the ring counts from.
    let setAt: Date

    /// The zone line's point at **exactly** this zone, duration and incline — its
    /// ten-visit mean — over 20:00 as well, where the point is never drawn. Nil where
    /// nothing has been held there, and without zones. **No backfill**: a lower zone or a
    /// longer duration at this intensity is another point's number, never this one's.
    let current: Double?

    /// Where the ring counts from: the point over the entries dated **strictly before**
    /// `setAt`, or else the point as of the first visit on it after. Nil while there is no
    /// point at all. **`current >= origin` does not hold by construction**, unlike
    /// strength's: a slower visit can pull the point back under it.
    let origin: Double?

    init?(
        zone: Int?,
        duration: Int?,
        intensity: Double?,
        incline: Double?,
        setAt: Date?,
        entries: [Entry],
        zones: HeartRateZones?,
        unit: ErgUnit,
        distanceUnit: DistanceUnit,
        calendar: Calendar = .current
    ) {
        guard let zone, let duration, let intensity, let setAt else { return nil }
        guard !unit.hasIncline || incline != nil else { return nil }
        self.unit = unit
        self.distanceUnit = distanceUnit
        self.zone = zone
        self.duration = duration
        self.intensity = intensity
        self.incline = unit.hasIncline ? incline : nil
        self.setAt = setAt
        let point = { (entries: [Entry]) in
            ZoneLine(entries: entries, zones: zones, unit: unit, zone: zone, incline: incline ?? 0, calendar: calendar)
                .point(at: duration)?.intensity
        }
        current = point(entries)

        // The point as it stood when the goal was named. With nothing held there yet, the
        // point as of your first visit on it after — that visit's own entries, since none
        // before `setAt` sits at this point.
        if let before = point(entries.filter { $0.date < setAt }) {
            origin = before
        } else {
            let visits = Set(entries.filter { $0.date >= setAt }.map { calendar.startOfDay(for: $0.date) }).sorted()
            origin = visits.lazy.compactMap { visit in
                let end = calendar.date(byAdding: .day, value: 1, to: visit)!
                return point(entries.filter { $0.date < end })
            }.first
        }
    }

    // MARK: - Reading it

    /// The point's mean meets the goal: `>=`, or `<=` on a split, where lower is harder.
    /// Compared in whole steps, never in binary.
    var isReached: Bool {
        gap == 0
    }

    /// How many of the unit's steps are left between the point and the goal — zero once
    /// reached, and **nil with no point**, which is `not held yet` rather than a gap from
    /// zero.
    var gap: Int? {
        guard let current else { return nil }
        return max(0, unit.hardness(intensity) - unit.hardness(current))
    }

    /// How much of the way from the origin to the goal the point has come, in steps and
    /// reversed on a split: the ring's fill, **clamped to 0…1** — a point fallen back
    /// below its origin leaves the ring empty, not negative — and 1 once reached.
    var progress: Double {
        guard !isReached else { return 1 }
        guard let current, let origin else { return 0 }
        let done = unit.hardness(current) - unit.hardness(origin)
        let span = unit.hardness(intensity) - unit.hardness(origin)
        // An origin already past the goal, with the point since fallen short of it, has
        // no way left to measure: the ring is as empty as it is below the origin.
        guard span > 0 else { return 0 }
        return min(1, max(0, Double(done) / Double(span)))
    }

    // MARK: - Words

    /// `15.5 km/h · 6:00 in Z4 · 1 %`, `L12 · 10:00 in Z3` — the goal as every surface
    /// names it: its goal line, the unit change's notice and the lost-goal clause.
    var text: String {
        "\(EnduranceText.goalIntensity(intensity, unit, distanceUnit)) · \(pointText)"
    }

    /// What follows the goal on its line: `0.4 km/h to go`, `reached`, or `not held yet`.
    var status: String {
        guard let gap else { return String(localized: "not held yet") }
        return gap == 0 ? String(localized: "reached") : String(localized: "\(EnduranceText.steps(gap, unit, distanceUnit)) to go")
    }

    /// The goal line as VoiceOver says it: `Goal 15.5 kilometres per hour for 6 minutes in
    /// zone 4 at 1 percent incline, 0.4 kilometres per hour to go`, `…, reached` or
    /// `…, not held yet`.
    var spokenLine: String {
        let point = String(localized: "\(EnduranceText.spokenIntensity(intensity, unit, distanceUnit)) for \(spokenPoint)")
        let status = switch gap {
        case nil: String(localized: "not held yet")
        case 0: String(localized: "reached")
        case let gap?: String(localized: "\(EnduranceText.spokenSteps(gap, unit, distanceUnit)) to go")
        }
        return String(localized: "Goal \(point), \(status)")
    }

    /// What a unit change says of the goals it clears (SPEC §13.6): *Your goal of 260 W ·
    /// 10:00 in Z3 is cleared.* — the most recently set named, any others counted. Nil
    /// when there were none.
    static func clearedNotice(_ goals: [EnduranceGoal]) -> String? {
        guard let named = goals.max(by: { $0.setAt < $1.setAt }) else { return nil }
        let others = goals.count - 1
        return others == 0
            ? String(localized: "Your goal of \(named.text) is cleared.")
            : String(localized: "Your goal of \(named.text) and \(others) other goals are cleared.")
    }

    /// `pointText` as VoiceOver says it: `6 minutes in zone 4 at 1 percent incline`.
    var spokenPoint: String {
        let point = String(localized: "\(Spoken.duration(duration)) in zone \(zone)")
        return incline.map { String(localized: "\(point) at \(Spoken.incline($0))") } ?? point
    }

    /// `6:00 in Z4 · 1 %` — the point the goal names, with no number.
    var pointText: String {
        let point = String(localized: "\(EnduranceText.clock(duration)) in Z\(zone)")
        return incline.map { "\(point) · \(EnduranceText.incline($0)) %" } ?? point
    }
}

extension EnduranceText {

    /// A difference of `steps` in the unit's own step, never a converted one: `0.4 km/h`,
    /// `0.4 mph`, `12 W`, `2 s` (a split's tenths, trimmed), `2 levels`.
    static func steps(_ steps: Int, _ unit: ErgUnit, _ distance: DistanceUnit) -> String {
        let amount = Double(steps) * unit.step
        switch unit {
        case .speed:
            return "\(amount.formatted(.number.precision(.fractionLength(1)).grouping(.never))) \(distance.speedSymbol)"
        case .watts:
            return String(localized: "\(steps.formatted(.number.grouping(.never))) W")
        case .split:
            return String(localized: "\(amount.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))) s")
        case .level:
            return String(localized: "\(steps) levels")
        }
    }

    /// A difference of `steps` in the unit's own step, as `steps(_:_:_:)` writes it:
    /// `0.4 kilometres per hour`, `12 watts`, `2 seconds`, `2 levels`.
    static func spokenSteps(_ steps: Int, _ unit: ErgUnit, _ distance: DistanceUnit) -> String {
        let amount = Double(steps) * unit.step
        switch unit {
        case .speed:
            return "\(amount.formatted(.number.precision(.fractionLength(1)).grouping(.never))) \(distance.spokenSpeedName)"
        case .watts:
            return String(localized: "\(steps) watts")
        case .split:
            return Spoken.seconds(amount, written: amount.formatted(.number.precision(.fractionLength(0...1)).grouping(.never)))
        case .level:
            return String(localized: "\(steps) levels")
        }
    }
}
