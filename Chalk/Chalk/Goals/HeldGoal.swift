import Foundation

/// A goal of either half as the repairs see it — strength's `Goal` (ADR-0004) or an
/// erg's `EnduranceGoal` (ADR-0007). A merge or a kind change does not judge a goal; it
/// only weighs one against another by **the moment it was set** and names the survivor,
/// so that is all this asks of them (SPEC §7.5, §8, §13.11).
///
/// Read through `GoalScope.heldGoal`, which picks the half from the scope's owner.
protocol HeldGoal {
    /// When the goal was last set — the shared `goalSetAt`, which the most recently set
    /// goal wins on.
    var setAt: Date { get }

    /// The goal as every surface names it: `140 × 5`, `15.5 km/h · 6:00 in Z4 · 1 %`.
    var text: String { get }
}

extension HeldGoal {

    /// The lost-goal clause: **one sentence for one rule**, said word for word by the kind
    /// change (SPEC §8) and the merge (§7.5) wherever two goals meet and the most recently
    /// set wins, in either half (§13.11). It names this goal, the survivor, and counts the
    /// ones that go.
    func lostGoalClause(clearing cleared: Int) -> String {
        let others = cleared == 1 ? "1 other goal is" : "\(cleared) other goals are"
        return "Your goal of \(text) is kept; \(others) cleared."
    }
}

extension Goal: HeldGoal {}

extension EnduranceGoal: HeldGoal {}
