import Foundation

/// The machine hint on an erg (SPEC §13.8, §5.4 carried over): on a gym-bound erg whose
/// machine in scope has no entries, one dimmed line quoting a sibling machine's line —
/// `No entries here — 6:00 in Z4 at 15.0 km/h · 1 % on Technogym Run · Urban Gym`.
///
/// **Never part of any line.** Text, visibly another machine's numbers: nothing is drawn
/// from here and no seed is taken from here. It reads the erg's own machines only, never
/// another erg's.
struct ErgMachineHint: Equatable {

    /// `6:00 in Z4 at 15.0 km/h · 1 % on Technogym Run · Urban Gym` — the clause the
    /// lead-in wraps.
    let text: String
    /// `text` as VoiceOver says it: `6 minutes in zone 4 at 15.0 kilometres per hour, 1
    /// percent incline, on Technogym Run at Urban Gym`.
    let spoken: String

    /// The line under the empty state's text, as strength's `MachineHint.emptyStateLine`.
    var emptyStateLine: String { "No entries here — \(text)" }

    /// `emptyStateLine` as VoiceOver says it.
    var spokenEmptyStateLine: String { "No entries here. \(spoken)" }

    /// The hint for one gym-bound erg screen, or `nil` where there is nothing honest to say:
    ///
    /// - a **transferable** erg, whose numbers are not kept per machine;
    /// - a machine that **has a valid interval of its own** — the screen has a line to show;
    /// - **zones not set**, so no point has a zone;
    /// - a sibling with **no valid interval**, or whose most recent one is **not a point
    ///   on its line** (over 20:00) — never another point instead (§5.4's rule).
    ///
    /// `zones` and `distanceUnit` are passed in, read live by the caller (ADR-0005).
    static func lookUp(
        _ erg: Exercise,
        scopedTo machine: Machine?,
        zones: HeartRateZones?,
        distanceUnit: DistanceUnit
    ) -> ErgMachineHint? {
        guard erg.isErg, erg.isGymBound, let unit = erg.ergUnit, let zones else { return nil }
        guard !MachineScope.entries(of: erg, on: machine).contains(where: \.isAnInterval) else { return nil }

        // The entry the lap-list sheet would seed from on that machine.
        guard let sibling = sibling(of: erg, scopedTo: machine),
              let latest = LastInterval.latestEntry(in: sibling.entries ?? [])
        else { return nil }

        let zone = zones.zone(of: latest.averageHeartRate)
        let line = ZoneLine(entries: sibling.entries ?? [], zones: zones, unit: unit, zone: zone, incline: latest.incline)
        guard let point = line.points.first(where: { $0.duration == latest.duration }) else { return nil }

        var text = "\(EnduranceText.clock(point.duration)) in Z\(zone) at \(EnduranceText.intensity(point.intensity, unit, distanceUnit, pace: false))"
        // As the written form: incline on a speed erg only, and left out at 0 % (SPEC §13.2).
        let incline = ErgUnit.roundedIncline(latest.incline)
        if unit.hasIncline, incline > 0 { text += " · \(EnduranceText.incline(incline)) %" }
        text += " on \(sibling.caption)"

        var spoken = "\(Spoken.duration(point.duration)) in zone \(zone) at \(EnduranceText.spokenIntensity(point.intensity, unit, distanceUnit))"
        if unit.hasIncline, incline > 0 { spoken += ", \(Spoken.incline(incline))," }
        spoken += " on \(sibling.spokenCaption)"
        return ErgMachineHint(text: text, spoken: spoken)
    }

    /// **The same model at another gym** — a case-insensitive equal model name — that has
    /// been logged on, the most recent of them; otherwise `MachineHint`'s most recently
    /// used sibling.
    private static func sibling(of erg: Exercise, scopedTo machine: Machine?) -> Machine? {
        if let machine, let model = ErgModelMatch.model(of: machine) {
            let sameModel = (erg.machines ?? []).filter {
                $0 !== machine
                    && $0.gym?.id != machine.gym?.id
                    && $0.lastLogged != nil
                    && ErgModelMatch.model(of: $0)?.caseInsensitiveCompare(model) == .orderedSame
            }
            if let match = MachineScope.byRecency(sameModel).first { return match }
        }
        return MachineHint.sibling(of: erg, scopedTo: machine)
    }
}
