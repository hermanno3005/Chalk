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

    /// The endurance goal set here, judged against this scope's entries and `zones`, and
    /// written in `distanceUnit`, both read live by the caller. **Nil on a lift**, and
    /// unless every field is set — a speed goal with its incline.
    ///
    /// `entries` judges it against those rather than all of this scope's — the lap-list
    /// sheet's save, which asks whether the goal was reached without what it writes.
    func enduranceGoal(
        judgedAgainst entries: [Entry]? = nil,
        zones: HeartRateZones?,
        distanceUnit: DistanceUnit,
        calendar: Calendar = .current
    ) -> EnduranceGoal? {
        guard let unit else { return nil }
        let stored: (zone: Int?, duration: Int?, intensity: Double?, incline: Double?, setAt: Date?) = switch self {
        case .exercise(let e): (e.goalZone, e.goalDuration, e.goalIntensity, e.goalIncline, e.goalSetAt)
        case .machine(let m): (m.goalZone, m.goalDuration, m.goalIntensity, m.goalIncline, m.goalSetAt)
        }
        return EnduranceGoal(
            zone: stored.zone,
            duration: stored.duration,
            intensity: stored.intensity,
            incline: stored.incline,
            setAt: stored.setAt,
            entries: entries ?? self.entries,
            zones: zones,
            unit: unit,
            distanceUnit: distanceUnit,
            calendar: calendar
        )
    }

    /// **Setting an endurance goal**: writes its four fields and stamps the moment,
    /// replacing whatever goal was here. The incline is kept on a speed erg only; every
    /// other unit stores none.
    func set(zone: Int, duration: Int, intensity: Double, incline: Double?, at date: Date = .now) {
        let incline = unit?.hasIncline == true ? incline : nil
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

    // MARK: - Repairs (SPEC §7.5, §8, §13.11)

    /// The goal held here **in the owner's half** — an erg's scope holds an endurance goal,
    /// a lift's a strength one, and the half is read from the owner, never from which
    /// fields happen to be set (§13.1). What the repairs weigh by `setAt` and name.
    ///
    /// Read without zones: a repair carries the fields and never judges the goal, so
    /// whether it is reached plays no part. `distanceUnit` is the scale its words write a
    /// speed goal in.
    func heldGoal(distanceUnit: DistanceUnit) -> (any HeldGoal)? {
        unit == nil ? goal : enduranceGoal(zones: nil, distanceUnit: distanceUnit)
    }

    /// Moves the goal set at `source` here, **keeping its `goalSetAt`** — the goal is the
    /// same goal wherever it lands, so its ring still counts from the moment it was named
    /// — and clears `source`. The kind change's move and pool (SPEC §8), and the merge's
    /// survivor (§7.5), **in either half** (§13.11).
    func takeGoal(from source: GoalScope) {
        // The fields move as they are: the scale they are on plays no part.
        switch source.heldGoal(distanceUnit: .km) {
        case let goal as Goal:
            set(reps: goal.reps, weight: goal.weight, at: goal.setAt)
        case let goal as EnduranceGoal:
            set(zone: goal.zone, duration: goal.duration, intensity: goal.intensity, incline: goal.incline, at: goal.setAt)
        default:
            break
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
