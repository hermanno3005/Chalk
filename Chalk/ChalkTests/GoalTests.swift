import Foundation
import Testing

@testable import Chalk

/// The goal's derivation (ADR-0004): reached, the gap, the origin and the ring's fill,
/// all read off the scope's entries each time and none of them stored.
///
/// Not one of these builds a `ModelContainer` — `Goal` is a plain struct over `[Entry]`,
/// exactly as `RepMaxCurve` is.
@Suite("Goal")
struct GoalTests {

    private let setAt = Date(timeIntervalSince1970: 1_700_000_000)
    private var before: Date { setAt.addingTimeInterval(-86_400) }
    private var after: Date { setAt.addingTimeInterval(86_400) }

    private func goal(reps: Int = 5, weight: Double = 140, _ entries: [Entry]) -> Goal? {
        Goal(reps: reps, weight: weight, setAt: setAt, entries: entries)
    }

    // MARK: - No goal

    @Test("A partly filled set of fields is no goal", arguments: [
        (Int?.none, Double?.some(140), Date?.some(Date(timeIntervalSince1970: 0))),
        (Int?.some(5), Double?.none, Date?.some(Date(timeIntervalSince1970: 0))),
        (Int?.some(5), Double?.some(140), Date?.none),
        (Int?.none, Double?.none, Date?.none),
    ])
    func aPartialTripleIsNoGoal(reps: Int?, weight: Double?, setAt: Date?) {
        #expect(Goal(reps: reps, weight: weight, setAt: setAt, entries: []) == nil)
    }

    @Test("All three fields make a goal")
    func aFullTripleIsAGoal() throws {
        let goal = try #require(Goal(reps: 5, weight: 140, setAt: setAt, entries: []))
        #expect(goal.reps == 5)
        #expect(goal.weight == 140)
    }

    // MARK: - Reached

    @Test("A goal is reached at exactly its weight")
    func reachedAtExactlyTheWeight() throws {
        let goal = try #require(goal([Entry(reps: 5, weight: 140, date: after)]))
        #expect(goal.isReached)
        #expect(goal.gap == 0)
    }

    @Test("A goal is reached above its weight")
    func reachedAboveTheWeight() throws {
        let goal = try #require(goal([Entry(reps: 5, weight: 142.5, date: after)]))
        #expect(goal.isReached)
        #expect(goal.gap == 0)
    }

    @Test("A goal is not reached just below its weight")
    func notReachedBelowTheWeight() throws {
        let goal = try #require(goal([Entry(reps: 5, weight: 137.5, date: after)]))
        #expect(!goal.isReached)
        #expect(goal.gap == 2.5)
    }

    @Test("A 1-rep goal is reached by 5-rep work")
    func aOneRepGoalIsReachedByHigherRepWork() throws {
        let goal = try #require(goal(reps: 1, weight: 95, [Entry(reps: 5, weight: 95, date: after)]))
        #expect(goal.isReached)
    }

    @Test("A goal above 12 reps is judged off the drawn axis")
    func aGoalAboveTwelveReps() throws {
        let entries = [
            Entry(reps: 15, weight: 40, date: after),
            Entry(reps: 12, weight: 60, date: after),
        ]
        let goal = try #require(goal(reps: 15, weight: 50, entries))
        #expect(goal.current == 40)
        #expect(!goal.isReached)
        #expect(goal.gap == 10)
    }

    // MARK: - The gap

    @Test("With nothing logged the gap is the whole weight")
    func theGapWithNothingLogged() throws {
        let goal = try #require(goal([]))
        #expect(goal.current == nil)
        #expect(goal.gap == 140)
        #expect(!goal.isReached)
    }

    @Test("With nothing reaching the rep count the gap is the whole weight")
    func theGapWithNothingAtThatRepCount() throws {
        let goal = try #require(goal([Entry(reps: 3, weight: 130, date: after)]))
        #expect(goal.gap == 140)
    }

    // MARK: - The origin

    @Test("The origin is the best before the goal was set")
    func theOriginIsTheBestBeforeSetting() throws {
        let goal = try #require(goal([
            Entry(reps: 5, weight: 100, date: before),
            Entry(reps: 5, weight: 120, date: after),
        ]))
        #expect(goal.origin == 100)
        #expect(goal.current == 120)
    }

    @Test("An entry at the same instant as the goal does not count toward the origin")
    func theOriginExcludesTheSameInstant() throws {
        let goal = try #require(goal([
            Entry(reps: 5, weight: 100, date: before),
            Entry(reps: 5, weight: 110, date: setAt),
        ]))
        #expect(goal.origin == 100)
    }

    @Test("With no earlier entries the origin is zero")
    func theOriginIsZeroWithNothingEarlier() throws {
        let goal = try #require(goal([Entry(reps: 5, weight: 70, date: after)]))
        #expect(goal.origin == 0)
        #expect(goal.progress == 0.5)
    }

    // MARK: - Progress

    @Test("Progress is the share of the gap closed since the goal was set")
    func progressCountsFromTheOrigin() throws {
        let goal = try #require(goal([
            Entry(reps: 5, weight: 100, date: before),
            Entry(reps: 5, weight: 130, date: after),
        ]))
        #expect(goal.progress == 0.75)
    }

    @Test("Progress is zero when nothing has moved since the goal was set")
    func progressIsZeroAtTheOrigin() throws {
        let goal = try #require(goal([Entry(reps: 5, weight: 100, date: before)]))
        #expect(goal.progress == 0)
    }

    @Test("Progress is 1 once reached, however far past")
    func progressIsOneWhenReached() throws {
        let goal = try #require(goal([
            Entry(reps: 5, weight: 100, date: before),
            Entry(reps: 5, weight: 160, date: after),
        ]))
        #expect(goal.progress == 1)
    }

    @Test("Progress is 1 for a goal that was already reached when it was set")
    func progressIsOneWhenSetBelowTheBest() throws {
        let goal = try #require(goal(weight: 90, [Entry(reps: 5, weight: 100, date: before)]))
        #expect(goal.isReached)
        #expect(goal.progress == 1)
    }

    @Test("Progress stays within 0…1")
    func progressIsClamped() throws {
        let goals = try [
            #require(goal([])),
            #require(goal([Entry(reps: 5, weight: 139, date: before)])),
            #require(goal([Entry(reps: 5, weight: 300, date: after)])),
        ]
        for goal in goals {
            #expect((0...1).contains(goal.progress))
        }
    }

    // MARK: - Derived, never stored

    @Test("Editing an entry down un-reaches the goal and lowers the origin")
    func aDownwardEditUnreachesAndLowersTheOrigin() throws {
        let earlier = Entry(reps: 5, weight: 120, date: before)
        let reaching = Entry(reps: 5, weight: 140, date: after)
        let entries = [earlier, reaching]
        #expect(try #require(goal(entries)).isReached)

        reaching.weight = 130
        earlier.weight = 110

        let goal = try #require(goal(entries))
        #expect(!goal.isReached)
        #expect(goal.gap == 10)
        #expect(goal.origin == 110)
        #expect(goal.progress == 20.0 / 30.0)
    }
}
