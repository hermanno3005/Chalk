import Foundation

/// Where a goal lives, and the one place its three raw fields are read or written
/// (ADR-0004): **the exercise for a free-weight exercise, one machine for a gym-bound
/// one**. Screens ask this for a `Goal` and never touch `goalReps`, `goalWeight` or
/// `goalSetAt` themselves, so a partly filled set can never be read as a goal.
///
/// Saving is the caller's: this changes the model objects and nothing else.
enum GoalScope {
    case exercise(Exercise)
    case machine(Machine)

    /// The scope a screen scoped to `machine` is showing — **nil for a gym-bound
    /// exercise with no machine yet**, which has nowhere to hold a goal. Borrowing a
    /// sibling machine's goal is never an answer.
    init?(exercise: Exercise, machine: Machine?) {
        guard exercise.isGymBound else {
            self = .exercise(exercise)
            return
        }
        guard let machine else { return nil }
        self = .machine(machine)
    }

    /// The entries a goal here is judged against — the same scope the curve derives
    /// from (SPEC §5.3).
    var entries: [Entry] {
        switch self {
        case .exercise(let exercise): exercise.entries ?? []
        case .machine(let machine): machine.entries ?? []
        }
    }

    /// The goal set here, judged against this scope's entries. Nil unless all three
    /// fields are set.
    var goal: Goal? { goal(judgedAgainst: entries) }

    /// The goal set here, judged against `entries` rather than all of this scope's —
    /// the log sheet's edit, which leaves out the entry being corrected.
    func goal(judgedAgainst entries: [Entry]) -> Goal? {
        switch self {
        case .exercise(let exercise):
            Goal(reps: exercise.goalReps, weight: exercise.goalWeight, setAt: exercise.goalSetAt, entries: entries)
        case .machine(let machine):
            Goal(reps: machine.goalReps, weight: machine.goalWeight, setAt: machine.goalSetAt, entries: entries)
        }
    }

    /// **Setting a goal**: writes all three fields and stamps the moment, which replaces
    /// whatever goal was here and restarts the ring from where you stand now.
    func set(reps: Int, weight: Double, at date: Date = .now) {
        write(reps: reps, weight: weight, setAt: date)
    }

    /// **Clearing a goal**: all three fields back to nil. Besides setting, the only
    /// write a goal has — a kind change carries one across scopes with the two together.
    func clear() {
        write(reps: nil, weight: nil, setAt: nil)
    }

    /// Moves the goal set at `source` here, **keeping its `goalSetAt`** — the goal is the
    /// same goal wherever it lands, so its ring still counts from the moment it was named
    /// — and clears `source`. The kind change's move and pool (SPEC §8).
    func takeGoal(from source: GoalScope) {
        if let goal = source.goal {
            set(reps: goal.reps, weight: goal.weight, at: goal.setAt)
        }
        source.clear()
    }

    private func write(reps: Int?, weight: Double?, setAt: Date?) {
        switch self {
        case .exercise(let exercise):
            exercise.goalReps = reps
            exercise.goalWeight = weight
            exercise.goalSetAt = setAt
        case .machine(let machine):
            machine.goalReps = reps
            machine.goalWeight = weight
            machine.goalSetAt = setAt
        }
    }
}
