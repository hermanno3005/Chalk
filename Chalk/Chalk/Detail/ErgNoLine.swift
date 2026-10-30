import Foundation

/// What the erg detail screen shows where a zone has no line on the scope and incline in
/// view (SPEC §13.8): text where the chart would be — `No Z4 on this machine yet.` /
/// `Nothing you've logged here averaged 158–169 bpm.` — and under it up to two quotes from
/// the nearest zones above and below that do have one.
///
/// This is what makes a first visit useful: it often lands only in Z5, and Z5 still says
/// where Z4 must be.
///
/// Read off an `ErgReading`, so it shares the screen's lines and selection rather than
/// deriving its own. A zone whose only entries are over 20:00 has no line, so it lands
/// here too, with the reading's over-20:00 caption under the text.
struct ErgNoLine: Equatable {

    /// One neighbouring zone's point: `Z5 3:00 at 16.5 km/h — too hard`.
    struct Quote: Equatable {
        let zone: Int
        /// The quote as VoiceOver says it: `Zone 5, 3 minutes at 16.5 kilometres per
        /// hour, too hard`.
        let spoken: String
        /// The quote without its zone — `3:00 at 16.5 km/h — too hard` — for a view that
        /// draws the zone as a tag of its own.
        let clause: String

        var text: String { String(localized: "Z\(zone) \(clause)") }
    }

    let title: String
    let detail: String
    /// `title` and `detail` as VoiceOver says them.
    let spokenTitle: String
    let spokenDetail: String

    /// The nearest zone above with a line, then the nearest below — none, one or both.
    let quotes: [Quote]

    /// - Parameter place: what the scope is called in the title — `machine` on a gym-bound
    ///   erg, `erg` on a transferable one.
    init?(_ reading: ErgReading, place: String) {
        guard let selection = reading.selection, let zones = reading.zones, let unit = reading.unit,
              !reading.hasLine(selection.zone)
        else { return nil }
        title = String(localized: "No Z\(selection.zone) on this \(place) yet.")
        detail = String(localized: "Nothing you've logged here averaged \(zones.range(of: selection.zone)).")
        spokenTitle = String(localized: "No zone \(selection.zone) on this \(place) yet.")
        spokenDetail = String(localized: "Nothing you've logged here averaged \(zones.spokenRange(of: selection.zone)).")

        let withLines = ZoneLine.zones.filter(reading.hasLine)
        let above = withLines.first { $0 > selection.zone }
        let below = withLines.last { $0 < selection.zone }
        quotes = [(above, String(localized: "too hard")), (below, String(localized: "too easy"))].compactMap { zone, verdict in
            // `.points` holds on-axis durations only, so a quote never reads past 20:00.
            guard let zone, let points = reading.lines[zone]?.points,
                  let point = Self.nearest(to: selection.duration, in: points)
            else { return nil }
            return Quote(
                zone: zone,
                spoken: String(localized: "Zone \(zone), \(Spoken.duration(point.duration)) at \(EnduranceText.spokenIntensity(point.intensity, unit, reading.distanceUnit)), \(verdict)"),
                clause: String(localized: "\(EnduranceText.clock(point.duration)) at \(EnduranceText.intensity(point.intensity, unit, reading.distanceUnit, pace: false)) — \(verdict)")
            )
        }
    }

    /// The point at the duration closest to the selection — the shorter of two equally
    /// near, as the scrub snaps.
    private static func nearest(to duration: Int, in points: [ZoneLine.Point]) -> ZoneLine.Point? {
        points.min { abs($0.duration - duration) < abs($1.duration - duration) }
    }
}
