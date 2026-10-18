import Foundation

/// Where a goal lives, and the one place its raw fields are read or written
/// (ADR-0004): **the exercise for a free-weight exercise, one machine for a gym-bound
/// one**. Screens ask this for a `Goal` and never touch `goalReps`, `goalWeight` or
/// `goalSetAt` themselves, so a partly filled set can never be read as a goal. **An erg's
/// scope works the same way** — the erg while transferable, one machine while gym-bound —
/// for an `EnduranceGoal` over the four endurance fields (ADR-0007).
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

    // MARK: - Endurance (ADR-0007)

    /// The erg this scope belongs to's unit — what an endurance goal here is written in.
    /// Nil on a lift's scope, which holds no endurance goal.
    var unit: ErgUnit? {
        switch self {
        case .exercise(let exercise): exercise.ergUnit
        case .machine(let machine): machine.exercise?.ergUnit
        }
    }

    /// The endurance goal set here, judged against this scope's entries and `zones`, read
    /// live by the caller. **Nil on a lift**, and unless every field is set — a speed goal
    /// with its incline.
    func enduranceGoal(zones: HeartRateZones?, calendar: Calendar = .current) -> EnduranceGoal? {
        guard let unit else { return nil }
        let fields: (Int?, Int?, Double?, Double?, Date?) = switch self {
        case .exercise(let e): (e.goalZone, e.goalDuration, e.goalIntensity, e.goalIncline, e.goalSetAt)
        case .machine(let m): (m.goalZone, m.goalDuration, m.goalIntensity, m.goalIncline, m.goalSetAt)
        }
        return EnduranceGoal(
            zone: fields.0,
            duration: fields.1,
            intensity: fields.2,
            incline: fields.3,
            setAt: fields.4,
            entries: entries,
            zones: zones,
            unit: unit,
            calendar: calendar
        )
    }

    /// **Setting an endurance goal**: writes its four fields and stamps the moment,
    /// replacing whatever goal was here. The incline is kept on a speed erg only; every
    /// other unit stores none.
    func set(zone: Int, duration: Int, intensity: Double, incline: Double?, at date: Date = .now) {
        let incline = unit == .speed ? incline : nil
        switch self {
        case .exercise(let exercise):
            exercise.goalZone = zone
            exercise.goalDuration = duration
            exercise.goalIntensity = intensity
            exercise.goalIncline = incline
            exercise.goalSetAt = date
        case .machine(let machine):
            machine.goalZone = zone
            machine.goalDuration = duration
            machine.goalIntensity = intensity
            machine.goalIncline = incline
            machine.goalSetAt = date
        }
    }

    // MARK: - Strength (ADR-0004)

    /// **Setting a goal**: writes all three fields and stamps the moment, which replaces
    /// whatever goal was here and restarts the ring from where you stand now.
    func set(reps: Int, weight: Double, at date: Date = .now) {
        write(reps: reps, weight: weight, setAt: date)
    }

    /// **Clearing a goal**: all seven goal fields back to nil, **both halves' alike**
    /// (ADR-0008). A row is one half by construction, so clearing never asks which
    /// half's goal it holds, and nothing of the other half's can outlive a clear. Besides
    /// setting, the only write a goal has — a kind change or a merge carries one across
    /// scopes with the two together, and a unit change clears through here.
    func clear() {
        write(reps: nil, weight: nil, setAt: nil)
        switch self {
        case .exercise(let exercise):
            exercise.goalZone = nil
            exercise.goalDuration = nil
            exercise.goalIntensity = nil
            exercise.goalIncline = nil
        case .machine(let machine):
            machine.goalZone = nil
            machine.goalDuration = nil
            machine.goalIntensity = nil
            machine.goalIncline = nil
        }
    }

    /// Moves the goal set at `source` here, **keeping its `goalSetAt`** — the goal is the
    /// same goal wherever it lands, so its ring still counts from the moment it was named
    /// — and clears `source`. The kind change's move and pool (SPEC §8), and the merge's
    /// survivor (§7.5).
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
