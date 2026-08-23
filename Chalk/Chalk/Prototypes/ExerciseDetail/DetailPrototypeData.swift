// PROTOTYPE — throwaway. Answers https://github.com/hermanno3005/Chalk/issues/7
// "Three variants of the exercise detail screen, switchable from a floating bottom
//  bar, over four sample datasets so the curve is judged sparse as well as full."
//
// Extends the log-entry-modal prototype's ProtoStore (same branch lineage) with:
//   - swappable sample datasets, so "what does this look like with 4 points?" is one tap
//   - gym / machine scoping, so the machine qualifier has something real to switch
//   - per-rep-count history, so "does history live on this screen?" can be tried
//
// No SwiftData, no persistence. Everything resets on relaunch.

import Foundation

/// The sample data shapes the ticket asks about. Cycled from the second pill.
enum ProtoDataset: String, CaseIterable {
    case fresh, sparse, typical, dense

    var name: String {
        switch self {
        case .fresh: "1 record"
        case .sparse: "4 records, gappy"
        case .typical: "6 records"
        case .dense: "26 records"
        }
    }
}

struct ProtoMachine: Identifiable, Hashable {
    let id = UUID()
    var gym: String
    var label: String

    var short: String { "\(label) · \(gym)" }
}

extension ProtoStore {
    /// Records visible right now: everything for a free-weight exercise, or just the
    /// current machine's for a gym-bound one. Per https://github.com/hermanno3005/Chalk/issues/2
    var scopedRecords: [ProtoRecord] {
        guard isGymBound else { return records }
        return records.filter { $0.machineID == currentMachineID }
    }

    /// Every record that counts toward best[n] — the list behind a tapped rep count.
    func history(atLeast reps: Int) -> [ProtoRecord] {
        scopedRecords.filter { $0.reps >= reps }.sorted { $0.date > $1.date }
    }

    /// Which record is currently *setting* best[n]. Nil when the rep count has no record at all.
    func sourceOfBest(at reps: Int) -> ProtoRecord? {
        history(atLeast: reps).max { lhs, rhs in
            (lhs.weight, lhs.date) < (rhs.weight, rhs.date)
        }
    }

    /// True when best[n] is inherited from a higher rep count rather than set at n itself —
    /// the visible face of monotonic backfill.
    func isInherited(at reps: Int) -> Bool {
        guard let source = sourceOfBest(at: reps) else { return false }
        return source.reps != reps
    }

    var currentMachine: ProtoMachine? {
        machines.first { $0.id == currentMachineID }
    }

    /// Other machines for this exercise at other gyms — hints, never part of the derivation.
    var siblingMachines: [ProtoMachine] {
        machines.filter { $0.id != currentMachineID }
    }

    func best(onMachine machine: ProtoMachine, at reps: Int) -> Double? {
        records.filter { $0.machineID == machine.id && $0.reps >= reps }.map(\.weight).max()
    }

    func load(_ dataset: ProtoDataset) {
        self.dataset = dataset
        let day = 86_400.0
        func rec(_ reps: Int, _ weight: Double, _ daysAgo: Double) -> ProtoRecord {
            ProtoRecord(reps: reps, weight: weight, date: .now.addingTimeInterval(-daysAgo * day))
        }

        switch dataset {
        case .fresh:
            records = [rec(8, 40, 1)]
        case .sparse:
            records = [rec(1, 70, 2), rec(3, 62.5, 9), rec(10, 42.5, 20), rec(12, 40, 34)]
        case .typical:
            records = [
                rec(5, 55, 3), rec(8, 47.5, 10), rec(3, 62.5, 17),
                rec(10, 42.5, 24), rec(1, 70, 31), rec(5, 52.5, 38),
            ]
        case .dense:
            records = (0..<26).map { i in
                let reps = [1, 2, 3, 5, 5, 6, 8, 8, 10, 12, 4, 7, 5][i % 13]
                let base = 75.0 - Double(reps) * 2.6
                return rec(reps, (base - Double(i) * 0.35).rounded(toNearest: 2.5), Double(i) * 4 + 2)
            }
        }

        // Gym-bound datasets need their records spread across the machines.
        if isGymBound {
            for index in records.indices {
                records[index].machineID = index % 4 == 3 ? machines[1].id : machines[0].id
            }
            currentMachineID = machines[0].id
        } else {
            for index in records.indices { records[index].machineID = nil }
        }
        lastSaved = nil
    }

    func setGymBound(_ bound: Bool) {
        isGymBound = bound
        load(dataset)
    }
}

extension Double {
    func rounded(toNearest step: Double) -> Double {
        (self / step).rounded() * step
    }
}

extension Date {
    var proAgo: String {
        let days = Int(Date.now.timeIntervalSince(self) / 86_400)
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        case ..<28: return "\(days)d ago"
        default: return "\(days / 7)w ago"
        }
    }

    var proShort: String {
        formatted(.dateTime.day().month(.abbreviated))
    }
}
