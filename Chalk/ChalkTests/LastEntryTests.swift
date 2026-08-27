import Foundation
import Testing

@testable import Chalk

/// The `8 × 52.5 kg · today` line the tiles and the resume card both draw (SPEC §7.1).
@Suite("Last entry")
struct LastEntryTests {

    private let now = Date.now

    private func days(_ count: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -count, to: now)!
    }

    @Test("The lift reads reps × weight in kilograms, with no trailing zero")
    func theLiftReadsRepsByWeight() {
        // The half plate is written the way the reader's locale writes a decimal
        // (`WeightText`), so the expectation asks for that rather than for a `.`.
        #expect(LastEntry(reps: 8, weight: 52.5, date: now).text(asOf: now)
            == "8 × \(52.5.kilogramsText) kg · today")
        #expect(LastEntry(reps: 1, weight: 60, date: now).text(asOf: now)
            == "1 × 60 kg · today")
    }

    @Test("Yesterday and the days before it are named, not dated")
    func recentDaysAreNamed() {
        #expect(LastEntry(reps: 5, weight: 60, date: days(1)).text(asOf: now)
            == "5 × 60 kg · yesterday")
        #expect(LastEntry(reps: 5, weight: 60, date: days(2)).text(asOf: now)
            == "5 × 60 kg · 2 days ago")
        #expect(LastEntry(reps: 5, weight: 60, date: days(6)).text(asOf: now)
            == "5 × 60 kg · 6 days ago")
    }

    @Test("A week back and further is a date")
    func olderEntriesAreDated() {
        let old = days(30)
        let dated = old.formatted(.dateTime.day().month(.abbreviated))

        #expect(LastEntry(reps: 5, weight: 60, date: old).text(asOf: now)
            == "5 × 60 kg · \(dated)")
    }

    @Test("A date past the year carries the year")
    func lastYearCarriesTheYear() {
        let old = Calendar.current.date(byAdding: .year, value: -2, to: now)!
        let dated = old.formatted(.dateTime.day().month(.abbreviated).year())

        #expect(LastEntry(reps: 5, weight: 60, date: old).text(asOf: now)
            == "5 × 60 kg · \(dated)")
    }

    @Test("A clock that runs ahead reads as today, never as a lift in the future")
    func futureDatesReadAsToday() {
        let ahead = Calendar.current.date(byAdding: .day, value: 3, to: now)!

        #expect(LastEntry(reps: 5, weight: 60, date: ahead).text(asOf: now)
            == "5 × 60 kg · today")
    }

    @Test("A zeroed row is not a lift and makes no line")
    func aZeroedRowIsNotALift() {
        #expect(LastEntry(Entry(reps: 0, weight: 0, date: now)) == nil)
        #expect(LastEntry(Entry(reps: 8, weight: 52.5, date: now))
            == LastEntry(reps: 8, weight: 52.5, date: now))
    }
}
