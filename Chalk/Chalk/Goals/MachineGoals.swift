import Foundation

/// The goals held by machines about to become one scope — a kind change pooling them
/// onto the exercise (SPEC §8), or a merge (§7.5). **The most recently set goal wins**:
/// it survives keeping its own `goalSetAt`, and the rest die with their machines.
///
/// One rule for both, so neither the winner nor the words about the loss can drift apart.
/// The order the machines arrive in plays no part — a merge's direction must not cost
/// you your only goal.
struct MachineGoals {

    /// The machines holding a goal, latest set first. Equal moments fall back to the
    /// machine's id, so even a tie picks the same winner whichever way round you ask.
    private let latestFirst: [(machine: Machine, goal: Goal)]

    init(_ machines: [Machine]) {
        latestFirst = machines
            .compactMap { machine in GoalScope.machine(machine).goal.map { (machine, $0) } }
            .sorted {
                $0.goal.setAt != $1.goal.setAt
                    ? $0.goal.setAt > $1.goal.setAt
                    : $0.machine.id.uuidString < $1.machine.id.uuidString
            }
    }

    /// The machine whose goal survives.
    var keeping: Machine? { latestFirst.first?.machine }

    /// The goal that survives.
    var kept: Goal? { latestFirst.first?.goal }

    /// The lost-goal clause, **only when a goal is lost** — nil with zero goals or one.
    var lostGoalClause: String? {
        guard let kept, latestFirst.count > 1 else { return nil }
        return kept.lostGoalClause(clearing: latestFirst.count - 1)
    }
}
