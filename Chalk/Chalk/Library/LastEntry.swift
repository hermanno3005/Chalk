import Foundation

/// What you last did for an exercise, written the one way Chalk writes it:
/// `8 × 52.5 kg · today` (SPEC §7.1). The tile subtitles and the resume card draw the
/// same line, so they say it in the same words.
///
/// A value copied off an `Entry` rather than the entry itself: the library holds it for
/// as long as a screen is up, and an entry can be edited or deleted underneath it.
struct LastEntry: Equatable {
    let reps: Int
    let weight: Double
    let date: Date

    /// `nil` for a row that is not a lift — a zeroed row is representable because the
    /// schema stays CloudKit-shaped (ADR-0001), and it is not something you did.
    init?(_ entry: Entry) {
        guard entry.isALift else { return nil }
        self.init(reps: entry.reps, weight: entry.weight, date: entry.date)
    }

    init(reps: Int, weight: Double, date: Date) {
        self.reps = reps
        self.weight = weight
        self.date = date
    }

    /// The most recent lift among `entries`, or `nil` when none of them is one.
    ///
    /// **The one definition of "what you last did"** — the tile subtitles, the resume
    /// card and the log sheet's seed (SPEC §6.3) all read it here, so *Log again* opens
    /// on the numbers the card is showing by construction rather than by agreement
    /// between two copies of the same `max`.
    static func latest(in entries: [Entry]) -> LastEntry? {
        latestEntry(in: entries).flatMap(LastEntry.init)
    }

    /// The entry itself, for the one caller that needs more off it than the words — the
    /// resume card's *Log again*, which hands the log sheet the machine that lift was
    /// logged on (SPEC §6.4). Same rule, one definition.
    static func latestEntry(in entries: [Entry]) -> Entry? {
        entries.filter(\.isALift).max { $0.date < $1.date }
    }

    /// The whole line. `asOf` is the day it is read on — passed rather than captured, so
    /// the text is derived at draw time and a screen left open past midnight still says
    /// today's word for a lift that is now yesterday's.
    func text(asOf now: Date = .now) -> String {
        "\(lift) · \(day(asOf: now))"
    }

    /// The numbers alone, without the date. The history sheet sets them apart from the
    /// day (SPEC §5.6) rather than running the two together as one line.
    var lift: String {
        "\(reps) × \(weight.kilogramsText) kg"
    }

    /// The day alone, in the same words.
    func day(asOf now: Date = .now) -> String {
        RelativeDay.text(for: date, asOf: now)
    }
}

/// How Chalk names a day: the near ones by name, the rest by date.
///
/// Deliberately not `RelativeDateTimeFormatter`, which measures elapsed time and calls
/// this morning's lift "8 hours ago". What matters here is which *day* you lifted on, so
/// the difference is counted in whole days from midnight to midnight.
private enum RelativeDay {
    static func text(for date: Date, asOf now: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        switch days {
        // A clock that runs ahead — or a device crossing a time zone — reads as today.
        // Chalk never says you lifted tomorrow.
        case ..<1: return "today"
        case 1: return "yesterday"
        case 2...6: return "\(days) days ago"
        default:
            let sameYear = calendar.component(.year, from: date)
                == calendar.component(.year, from: now)
            return sameYear
                ? date.formatted(.dateTime.day().month(.abbreviated))
                : date.formatted(.dateTime.day().month(.abbreviated).year())
        }
    }
}
