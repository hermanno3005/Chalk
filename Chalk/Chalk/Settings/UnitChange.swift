import Foundation
import SwiftData

/// A change to the weight or distance unit asked for on Settings (SPEC §15.2, ADR-0009),
/// waiting to be made.
///
/// It offers two acts. **Relabel**: every stored number stays as it is and only the scale
/// changes, which repairs a wrong pick at onboarding. Nothing in the store is touched,
/// because nothing converts at read time. **Convert** (`Convert`): every number on the
/// scale is rewritten onto the new one, which moving to a gym on the other scale asks for.
enum UnitChange: Equatable {
    case weights(WeightUnit)
    case distances(DistanceUnit)

    /// Whether anything is written on the scale this change moves yet: a lift or a strength
    /// goal for weights, and a speed erg's interval or speed goal for distances, each at
    /// either scope. Until there is, a change is just a change, with nothing to relabel.
    func isWritten(in context: ModelContext) throws -> Bool {
        let written = try self.written(in: context)
        return written.entries + written.goals > 0
    }

    /// How many entries and goals are written on the scale this change moves, which is
    /// what a convert rewrites and counts in its confirmation: every lift and strength goal,
    /// or every speed erg's interval and speed goal, each goal at either scope.
    func written(in context: ModelContext) throws -> (entries: Int, goals: Int) {
        switch self {
        case .weights:
            return try (
                context.fetchCount(Self.lifts),
                context.fetchCount(Self.exercisesWithAWeightGoal) + context.fetchCount(Self.machinesWithAWeightGoal)
            )
        case .distances:
            let ergs = try context.fetch(Self.speedErgs)
            return (
                ergs.reduce(0) { $0 + ($1.entries ?? []).count { $0.intensity > 0 } },
                ergs.reduce(0) { $0 + ($1.goalIntensity == nil ? 0 : 1) + ($1.machines ?? []).count { $0.goalIntensity != nil } }
            )
        }
    }

    /// Every lift: the entries whose weight is written on the weight unit's scale.
    static var lifts: FetchDescriptor<Entry> {
        FetchDescriptor(predicate: #Predicate { $0.exercise != nil && $0.reps >= 1 && $0.weight > 0 })
    }

    /// Every exercise holding a strength goal.
    static var exercisesWithAWeightGoal: FetchDescriptor<Exercise> {
        FetchDescriptor(predicate: #Predicate { $0.goalWeight != nil })
    }

    /// Every machine holding a strength goal.
    static var machinesWithAWeightGoal: FetchDescriptor<Machine> {
        FetchDescriptor(predicate: #Predicate { $0.goalWeight != nil })
    }

    /// Every speed erg: the ergs whose intervals and goals are written on the distance
    /// unit's scale.
    static var speedErgs: FetchDescriptor<Exercise> {
        let speed = ErgUnit.speed.rawValue
        return FetchDescriptor(predicate: #Predicate { $0.unit == speed })
    }

    /// The question a change asks once its scale has numbers, naming the scale as a
    /// restore's confirmation does: `Write weights in lb?`, `Write distances in miles?`.
    var title: String {
        switch self {
        case .weights: String(localized: "Write weights in \(scaleName)?")
        case .distances: String(localized: "Write distances in \(scaleName)?")
        }
    }

    /// What the question says, in words that leave no doubt which act moves a number.
    /// Relabel is named as the repair for a wrong pick and convert as the move to a gym on
    /// the other scale, which is what each is for (SPEC §15.2).
    var message: String {
        String(localized: "Relabel if you picked the wrong unit: every \(noun) and goal keeps its number and is written in \(symbol) instead. Convert if your gym uses \(symbol): every \(noun) and goal is rewritten in \(symbol).")
    }

    /// The answer that relabels: `Relabel as lb`, `Relabel as miles`.
    var relabelLabel: String {
        String(localized: "Relabel as \(scaleName)")
    }

    /// The answer that converts, which asks once more before it does: `Convert to lb…`,
    /// `Convert to miles…`.
    var convertLabel: String {
        String(localized: "Convert to \(scaleName)…")
    }

    /// What a convert's confirmation asks: `Convert weights to lb?`, `Convert distances to
    /// miles?`.
    var convertTitle: String {
        switch self {
        case .weights: String(localized: "Convert weights to \(scaleName)?")
        case .distances: String(localized: "Convert distances to \(scaleName)?")
        }
    }

    /// The grid a convert rounds to, in words: `the nearest half kilogram`, `the nearest
    /// pound`, `the nearest 0.1 mph`.
    var convertGrid: String {
        switch self {
        case .weights(.kg): String(localized: "the nearest half kilogram")
        case .weights(.lb): String(localized: "the nearest pound")
        case .distances(let unit): String(localized: "the nearest 0.1 \(unit.speedSymbol)")
        }
    }

    /// What the scale holds: `weight` or `speed`.
    private var noun: String {
        switch self {
        case .weights: String(localized: "weight")
        case .distances: String(localized: "speed")
        }
    }

    /// What the scale is called: `kg`, `lb`, `km` or `miles`.
    private var scaleName: String {
        switch self {
        case .weights(let unit): unit.symbol
        case .distances(let unit): unit.name
        }
    }

    /// The scale's symbol as a number is written in it: `kg`, `lb`, `km/h` or `mph`.
    var symbol: String {
        switch self {
        case .weights(let unit): unit.symbol
        case .distances(let unit): unit.speedSymbol
        }
    }

    /// Moves the scale and leaves every number where it is.
    func relabel(in defaults: UserDefaults) {
        switch self {
        case .weights(let unit): unit.save(to: defaults)
        case .distances(let unit): unit.save(to: defaults)
        }
    }
}
