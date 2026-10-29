import Foundation

/// A **rep-max card** (SPEC §15.5): one scope's twelve rep-maxes, as Siri or a Spotlight
/// tile shows them without opening Chalk.
///
/// **The scope is the one the detail screen opens on**, `MachineScope.opening`, so a tap
/// on the card lands on the same numbers. A phrase carries one value, the exercise, so the
/// card holds every rep count rather than the one you said, and can never answer the wrong
/// one. A plain value read off the store once, since the intent hands it to a view and a
/// dialog outside any context.
struct RepMaxCard: Equatable, Sendable {

    /// One rep count's rep-max.
    struct Cell: Equatable, Sendable {
        let reps: Int
        /// `best[reps]`, or nil where nothing is proven: an absent cell is *not yet
        /// proven*, never zero (SPEC §4).
        let weight: Double?
        let weightUnit: WeightUnit

        /// The weight with its unit, `95 kg`, or `—` on an unproven cell.
        var text: String {
            weight.map(weightUnit.text) ?? "—"
        }
    }

    let exerciseID: UUID
    let name: String
    /// The machine in scope, `label · gym`, on a gym-bound exercise that has one.
    let machine: String?
    /// One cell per rep count, 1 through 12.
    let cells: [Cell]
    /// `Nothing logged on Bench Press yet` where the scope holds no lift, in place of the
    /// grid; `nil` otherwise.
    let nothingLogged: String?

    init(exercise: Exercise, gyms: GymsModel, weightUnit: WeightUnit) {
        let machine = exercise.isGymBound
            ? MachineScope.opening(machines: exercise.machines ?? [], currentGym: gyms.currentGym)
            : nil
        let curve = RepMaxCurve(entries: MachineScope.entries(of: exercise, on: machine))

        exerciseID = exercise.id
        name = exercise.name
        self.machine = machine?.caption
        cells = RepMaxCurve.repRange.map { reps in
            Cell(reps: reps, weight: curve.best[reps], weightUnit: weightUnit)
        }
        nothingLogged = curve.entryCount == 0 ? "Nothing logged on \(exercise.name) yet" : nil
    }

    /// The card in words, the value the intent returns, so Siri can answer from the
    /// numbers where it doesn't show the card: `Bench Press: 110 kg × 1, 95 kg × 2, …`.
    var summary: String {
        if let nothingLogged { return nothingLogged }
        let scope = machine.map { "\(name) on \($0)" } ?? name
        let cells = cells.map { cell in
            cell.weight == nil ? "not yet proven × \(cell.reps)" : "\(cell.text) × \(cell.reps)"
        }
        return "\(scope): \(cells.joined(separator: ", "))"
    }
}
