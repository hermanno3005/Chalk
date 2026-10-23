import Foundation
import SwiftData

/// A change to the weight or distance unit asked for on Settings (SPEC §15.2, ADR-0009),
/// waiting to be made.
///
/// **Relabel** is the one act it offers so far: every stored number stays as it is and
/// only the scale changes, which repairs a wrong pick at onboarding. Nothing in the store
/// is touched, because nothing converts at read time.
enum UnitChange: Equatable {
    case weights(WeightUnit)
    case distances(DistanceUnit)

    /// Whether anything is written on the scale this change moves yet: a lift or a strength
    /// goal for weights, and a speed erg's interval or speed goal for distances, each at
    /// either scope. Until there is, a change is just a change, with nothing to relabel.
    func isWritten(in context: ModelContext) throws -> Bool {
        switch self {
        case .weights:
            return try context.fetchCount(FetchDescriptor<Entry>(predicate: #Predicate { $0.exercise != nil && $0.reps >= 1 && $0.weight > 0 })) > 0
                || context.fetchCount(FetchDescriptor<Exercise>(predicate: #Predicate { $0.goalWeight != nil })) > 0
                || context.fetchCount(FetchDescriptor<Machine>(predicate: #Predicate { $0.goalWeight != nil })) > 0
        case .distances:
            let speed = ErgUnit.speed.rawValue
            return try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.unit == speed })).contains { erg in
                erg.goalIntensity != nil
                    || (erg.entries ?? []).contains { $0.intensity > 0 }
                    || (erg.machines ?? []).contains { $0.goalIntensity != nil }
            }
        }
    }

    /// The question a change asks once its scale has numbers, naming the scale as a
    /// restore's confirmation does: `Write weights in lb?`, `Write distances in miles?`.
    var title: String {
        switch self {
        case .weights: "Write weights in \(scaleName)?"
        case .distances: "Write distances in \(scaleName)?"
        }
    }

    /// What the question says, in words that leave no doubt no number moves. Relabel is
    /// named as the repair for a wrong pick, which is what it is for (SPEC §15.2).
    var message: String {
        "Relabel if you picked the wrong unit: every \(noun) and goal keeps its number and is written in \(symbol) instead. No number is converted."
    }

    /// The answer that relabels: `Relabel as lb`, `Relabel as miles`.
    var relabelLabel: String {
        "Relabel as \(scaleName)"
    }

    /// What the scale holds: `weight` or `speed`.
    private var noun: String {
        switch self {
        case .weights: "weight"
        case .distances: "speed"
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
    private var symbol: String {
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
