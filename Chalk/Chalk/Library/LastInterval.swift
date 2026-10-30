import Foundation

/// What you last did on an erg, written the one way Chalk writes it (SPEC §13.2):
/// `6:00 at 15.0 km/h (4:00 /km) · 1 % · 168/174 bpm`. The endurance twin of
/// `LastEntry`, which the tile subtitles, the resume card and the lap-list sheet's seed
/// all read, so *Log again* opens on the numbers the card is showing.
///
/// A value copied off an `Entry`, as `LastEntry` is: the library holds it while a screen
/// is up, and an entry can be edited or deleted underneath it.
struct LastInterval: Equatable {
    let unit: ErgUnit
    let duration: Int
    let intensity: Double
    let incline: Double
    let averageHeartRate: Int
    let peakHeartRate: Int
    let date: Date

    /// `nil` for a row that is not a **valid interval**, or whose erg has no unit — it is
    /// not something you did on an erg.
    init?(_ entry: Entry) {
        guard entry.isAnInterval, let unit = entry.exercise?.ergUnit else { return nil }
        self.init(
            unit: unit,
            duration: entry.duration,
            intensity: entry.intensity,
            incline: entry.incline,
            averageHeartRate: entry.averageHeartRate,
            peakHeartRate: entry.peakHeartRate,
            date: entry.date
        )
    }

    init(
        unit: ErgUnit,
        duration: Int,
        intensity: Double,
        incline: Double,
        averageHeartRate: Int,
        peakHeartRate: Int,
        date: Date
    ) {
        self.unit = unit
        self.duration = duration
        self.intensity = intensity
        self.incline = incline
        self.averageHeartRate = averageHeartRate
        self.peakHeartRate = peakHeartRate
        self.date = date
    }

    /// The most recent valid interval among `entries`, or nil when none is one.
    static func latest(in entries: [Entry]) -> LastInterval? {
        latestEntry(in: entries).flatMap(LastInterval.init)
    }

    /// The entry itself, for the resume card, which needs its machine as well as its
    /// words. Same rule, one definition.
    static func latestEntry(in entries: [Entry]) -> Entry? {
        entries.filter(\.isAnInterval).max { $0.date < $1.date }
    }

    /// The resume card's line: the whole written form, heart rates included, and the day,
    /// a speed written in `distanceUnit`.
    func text(in distanceUnit: DistanceUnit, asOf now: Date = .now) -> String {
        "\(written(in: distanceUnit)) · \(day(asOf: now))"
    }

    /// What a tile says you did, before its day: `6:00 at 15.0 km/h` — **no heart rates and
    /// no pace**, so it stays short enough for a tile (SPEC §13.5).
    func tileText(in distanceUnit: DistanceUnit) -> String {
        setting(in: distanceUnit, pace: false)
    }

    /// The resume card's line as VoiceOver says it: the written form in words, pace and
    /// heart rates included, then the day.
    func spoken(in distanceUnit: DistanceUnit, asOf now: Date = .now) -> String {
        var parts = [String(localized: "\(Spoken.duration(duration)) at \(EnduranceText.spokenIntensity(intensity, unit, distanceUnit))")]
        if unit == .speed, intensity > 0 { parts.append(String(localized: "pace \(EnduranceText.spokenPace(intensity, distanceUnit))")) }
        if unit.hasIncline, incline > 0 { parts.append(Spoken.incline(incline)) }
        parts.append(String(localized: "average \(averageHeartRate), peak \(Spoken.heartRate(peakHeartRate))"))
        parts.append(day(asOf: now))
        return parts.joined(separator: ", ")
    }

    /// The tile's words as VoiceOver says them: `6 minutes at 15.0 kilometres per hour, 1
    /// percent incline`.
    func spokenTileText(in distanceUnit: DistanceUnit) -> String {
        var text = String(localized: "\(Spoken.duration(duration)) at \(EnduranceText.spokenIntensity(intensity, unit, distanceUnit))")
        if unit.hasIncline, incline > 0 { text += ", \(Spoken.incline(incline))" }
        return text
    }

    /// The day alone, in the words `LastEntry` uses.
    func day(asOf now: Date = .now) -> String {
        RelativeDay.text(for: date, asOf: now)
    }

    /// The written form (SPEC §13.2): average before peak, incline left out at 0 %.
    func written(in distanceUnit: DistanceUnit) -> String {
        String(localized: "\(setting(in: distanceUnit, pace: true)) · \(averageHeartRate)/\(peakHeartRate) bpm")
    }

    /// What you did and set: `6:00 at 15.0 km/h (4:00 /km) · 1 %`.
    private func setting(in distanceUnit: DistanceUnit, pace: Bool) -> String {
        var text = String(localized: "\(EnduranceText.clock(duration)) at \(EnduranceText.intensity(intensity, unit, distanceUnit, pace: pace))")
        if unit.hasIncline, incline > 0 { text += " · \(EnduranceText.incline(incline)) %" }
        return text
    }
}
