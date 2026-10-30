import Foundation

/// How a backup writes a date: ISO 8601 in UTC, with **every fractional digit the date
/// holds**, as `2026-10-22T21:59:55.521741Z`.
///
/// No built-in strategy is both readable and exact. `.iso8601` drops the fraction, and
/// `.secondsSince1970` moves the number onto another epoch in floating point and changes
/// about 40 % of dates. Exactness matters to Chalk: intervals saved together differ by
/// microseconds, and a goal's origin is the entries dated before `goalSetAt`.
///
/// So the fraction is spliced in from `timeIntervalSinceReferenceDate.description`, which
/// is the shortest decimal that reads back to the same bits, and reading rebuilds that
/// same decimal text and parses it as a `Double`.
enum BackupDate {

    /// `date` as a backup writes it. Fails for a date before 2001, which Chalk never holds:
    /// `description` truncates toward zero, so the second before 2001 would lose its sign.
    static func string(from date: Date) throws -> String {
        let interval = date.timeIntervalSinceReferenceDate
        let text = interval.description
        guard interval >= 0, interval.isFinite, !text.contains("e") else {
            throw EncodingError.invalidValue(date, EncodingError.Context(
                codingPath: [],
                debugDescription: "A backup holds no date before 2001"
            ))
        }
        let parts = text.split(separator: ".", maxSplits: 1)
        let whole = Date(timeIntervalSinceReferenceDate: Double(parts[0])!)
            .formatted(.iso8601)
        let fraction = parts.count == 2 ? parts[1] : "0"
        guard fraction != "0" else { return whole }
        return whole.dropLast() + ".\(fraction)Z"
    }

    /// The date a backup wrote as `string`, or `nil` when it is not one.
    static func date(from string: String) -> Date? {
        guard string.hasSuffix("Z") else { return nil }
        let parts = string.dropLast().split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let whole = try? Date("\(parts[0])Z", strategy: .iso8601) else { return nil }
        guard parts.count == 2 else { return whole }
        let fraction = parts[1]
        guard !fraction.isEmpty, fraction.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        let seconds = Int(whole.timeIntervalSinceReferenceDate)
        guard let interval = Double("\(seconds).\(fraction)") else { return nil }
        return Date(timeIntervalSinceReferenceDate: interval)
    }
}
