// PROTOTYPE — throwaway. Answers https://github.com/hermanno3005/Chalk/issues/6
// "Three variants of the log-entry modal, switchable from a floating bottom bar,
//  hosted on a rough exercise detail screen."
//
// No SwiftData, no persistence: state lives in memory and resets on relaunch.

import Foundation

struct ProtoRecord: Identifiable, Hashable {
    let id = UUID()
    var reps: Int
    var weight: Double
    var date: Date
}

/// Everything the prototype needs to feel like a real exercise with history.
@Observable
final class ProtoStore {
    var exerciseName = "Bench Press"
    var isGymBound = false
    var currentGym = "PureGym Islington"
    var records: [ProtoRecord]

    /// Set by whichever variant just saved, so the host screen can flash confirmation.
    var lastSaved: ProtoRecord?

    init() {
        let day = 86_400.0
        records = [
            ProtoRecord(reps: 5, weight: 55, date: .now.addingTimeInterval(-3 * day)),
            ProtoRecord(reps: 8, weight: 47.5, date: .now.addingTimeInterval(-10 * day)),
            ProtoRecord(reps: 3, weight: 62.5, date: .now.addingTimeInterval(-17 * day)),
            ProtoRecord(reps: 10, weight: 42.5, date: .now.addingTimeInterval(-24 * day)),
            ProtoRecord(reps: 1, weight: 70, date: .now.addingTimeInterval(-31 * day)),
            ProtoRecord(reps: 5, weight: 52.5, date: .now.addingTimeInterval(-38 * day)),
        ]
    }

    /// Monotonic backfill, per https://github.com/hermanno3005/Chalk/issues/3
    /// best[n] = max(weight) over all records with reps >= n
    func best(at reps: Int) -> Double? {
        records.filter { $0.reps >= reps }.map(\.weight).max()
    }

    var curve: [(reps: Int, weight: Double)] {
        (1...12).compactMap { n in best(at: n).map { (n, $0) } }
    }

    /// Epley ghost: seeded by the record with the highest estimated 1RM,
    /// projected back across the axis. Guidance only — never a record.
    var ghostCurve: [(reps: Int, weight: Double)] {
        guard let e1rm = records.map({ $0.weight * (1 + Double($0.reps) / 30) }).max() else { return [] }
        return (1...12).map { n in (n, e1rm / (1 + Double(n) / 30)) }
    }

    /// The most recent entry, whatever the rep count — the "do it again" seed.
    var mostRecent: ProtoRecord? {
        records.max(by: { $0.date < $1.date })
    }

    /// Distinct recent reps x weight combinations, newest first — the repeat chips.
    var recentCombos: [ProtoRecord] {
        var seen = Set<String>()
        return records.sorted(by: { $0.date > $1.date }).filter {
            let key = "\($0.reps)x\($0.weight)"
            return seen.insert(key).inserted
        }
    }

    func save(reps: Int, weight: Double) {
        let record = ProtoRecord(reps: reps, weight: weight, date: .now)
        records.append(record)
        lastSaved = record
    }

    /// What the modal can tell you *before* you save.
    func verdict(reps: Int, weight: Double) -> Verdict {
        guard reps >= 1, weight > 0 else { return .invalid }
        guard let current = best(at: reps) else { return .firstEver }
        if weight > current { return .newBest(by: weight - current, previous: current) }
        if weight == current { return .matchesBest }
        return .below(best: current)
    }

    enum Verdict {
        case invalid
        case firstEver
        case newBest(by: Double, previous: Double)
        case matchesBest
        case below(best: Double)
    }
}

extension Double {
    /// 55.0 -> "55", 52.5 -> "52.5"
    var kg: String {
        self == rounded() ? String(Int(self)) : String(format: "%.1f", self)
    }
}
