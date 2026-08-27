import Foundation
import Testing

@testable import Chalk

/// The near-name warning at gym creation (SPEC §7.4). **Duplicates are prevented, not
/// merged** — there is no gym merge, so the cheap moment to catch one is while it is
/// being typed.
@Suite("Gym name match")
struct GymNameMatchTests {

    @Test("The same name typed again is a match")
    func exactNameMatches() throws {
        let fixture = try LibraryFixture()
        let existing = fixture.gym("Fitness X")

        #expect(GymNameMatch.nearMatch(for: "Fitness X", among: [existing]) === existing)
    }

    @Test("Case, spacing and accents do not make it a different gym")
    func matchIgnoresCaseSpacingAndAccents() throws {
        let fixture = try LibraryFixture()
        let existing = fixture.gym("Café Gym")

        #expect(GymNameMatch.nearMatch(for: "  cafe   gym ", among: [existing]) === existing)
    }

    @Test("A typo away is a match")
    func oneTypoMatches() throws {
        let fixture = try LibraryFixture()
        let existing = fixture.gym("Fitness X")

        #expect(GymNameMatch.nearMatch(for: "Fitnes X", among: [existing]) === existing)
    }

    @Test("A name that only extends another is a match")
    func aLongerNameOverTheSameStemMatches() throws {
        let fixture = try LibraryFixture()
        let existing = fixture.gym("Fitness X")

        #expect(GymNameMatch.nearMatch(for: "Fitness X Kreuzberg", among: [existing]) === existing)
    }

    @Test("A genuinely different gym is not a match")
    func differentNamesDoNotMatch() throws {
        let fixture = try LibraryFixture()
        let existing = fixture.gym("Fitness X")

        #expect(GymNameMatch.nearMatch(for: "Old Barn", among: [existing]) == nil)
    }

    @Test("Short names are not collapsed into each other")
    func shortNamesAreNotCollapsed() throws {
        let fixture = try LibraryFixture()
        let existing = fixture.gym("RSG")

        #expect(GymNameMatch.nearMatch(for: "PSG", among: [existing]) == nil)
    }

    @Test("An archived gym still warns — it exists, it is only hidden")
    func archivedGymsStillMatch() throws {
        let fixture = try LibraryFixture()
        let archived = fixture.gym("Fitness X", isArchived: true)

        #expect(GymNameMatch.nearMatch(for: "Fitness X", among: [archived]) === archived)
    }

    @Test("A blank name matches nothing")
    func blankNameMatchesNothing() throws {
        let fixture = try LibraryFixture()
        let existing = fixture.gym("Fitness X")

        #expect(GymNameMatch.nearMatch(for: "   ", among: [existing]) == nil)
    }
}
