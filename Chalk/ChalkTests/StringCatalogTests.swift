import Foundation
import Testing

@testable import Chalk

/// Every user-facing string lives in the String Catalog, English only, and **a counted noun
/// takes its plural from the catalog**, never from a `count == 1` in code (SPEC §15.6). The
/// one exception is a noun drawn without its number, `rep` beside the big `1`, which the
/// catalog refuses as a plural and holds as two strings.
/// These pin the catalog's plural forms, which nothing else would notice going missing: a
/// key without its variations still reads, as `1 entries`.
@Suite("String Catalog")
struct StringCatalogTests {

    @Test("A counted noun is singular at one and plural otherwise")
    func countedNouns() {
        #expect(String(localized: "\(1) entries") == "1 entry")
        #expect(String(localized: "\(2) entries") == "2 entries")
        #expect(String(localized: "\(0) entries") == "0 entries")
        #expect(Spoken.reps(1) == "1 rep")
        #expect(Spoken.reps(5) == "5 reps")
        #expect(Spoken.duration(3_661) == "1 hour 1 minute 1 second")
        #expect(Spoken.duration(7_322) == "2 hours 2 minutes 2 seconds")
        #expect(Spoken.duration(0) == "0 seconds")
    }

    @Test("A sentence that counts takes its plural from the catalog too")
    func countingSentences() {
        #expect(String(localized: "First entry at \(1) reps") == "First entry at 1 rep")
        #expect(String(localized: "First goal at \(1) reps") == "First goal at 1 rep")
        #expect(String(localized: "Save \(1)") == "Save")
        #expect(String(localized: "Save \(5)") == "Save 5")
        #expect(String(localized: "Discard \(1) entries?") == "Discard this entry?")
        #expect(String(localized: "all \(1) entries") == "1 entry")
        #expect(String(localized: "all \(12) entries") == "all 12 entries")
        #expect(String(localized: "\(1) days ago") == "1 day ago")
    }

    @Test("A count is written with the grouping of where you are standing")
    func aCountIsGrouped() {
        let thousands = 1_240.formatted(.number)
        #expect(String(localized: "\(1_240) entries") == "\(thousands) entries")
    }

    @Test("A decimal takes its plural from its value: one at exactly 1, plural at 1.5")
    func decimalNouns() {
        let decimal = WeightText.decimalSeparator
        #expect(WeightUnit.kg.spokenText(1) == "1 kilogram")
        #expect(WeightUnit.kg.spokenText(1.5) == "1\(decimal)5 kilograms")
        #expect(WeightUnit.lb.spokenText(1) == "1 pound")
        #expect(WeightUnit.lb.spokenText(225) == "225 pounds")
    }
}
