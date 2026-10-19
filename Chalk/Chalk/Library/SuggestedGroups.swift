import Foundation
import SwiftData

/// The groups Chalk ships with, seeded once per half (SPEC §7.2, §13.5).
///
/// A **suggestion**, and nothing more: once seeded they are ordinary rows — renameable,
/// reorderable, deletable — and no screen ever falls back to this list. Which is why each
/// half's seed happens once and never again: restoring a group the user deleted would make
/// the suggestion a schema.
enum SuggestedGroups {

    /// `Compound` beside `Legs` is incoherent as a classification and entirely fine as a
    /// shelf you arranged yourself. The order is the order they seed in.
    static let names = ["Compound", "Legs", "Push", "Pull", "Core"]

    /// The endurance suggestion. **No *Other*** — Ungrouped is already the catch-all and
    /// sorts last — and **no *Ergs***, since every endurance machine is an erg, the
    /// treadmill included (SPEC §13.5).
    static let enduranceNames = ["Treadmills", "Rowing & Ski", "Bikes"]

    /// Set once strength's seed has run. It lives in `UserDefaults` rather than the store
    /// because it is not part of the record — the store holds training, and adding a
    /// sixth entity to hold one boolean would put it in every CloudKit mirror later.
    static let seededKey = "com.hermannaust.Chalk.suggestedGroupsSeeded"

    /// Endurance's own flag, so an install that seeded strength long ago still seeds
    /// endurance once.
    static let enduranceSeededKey = "com.hermannaust.Chalk.enduranceGroupsSeeded"

    static func names(for half: Half) -> [String] {
        switch half {
        case .strength: names
        case .endurance: enduranceNames
        }
    }

    static func seededKey(for half: Half) -> String {
        switch half {
        case .strength: seededKey
        case .endurance: enduranceSeededKey
        }
    }

    /// Seeds `half`'s groups if this install has never seeded them.
    ///
    /// The flag is the real gate; the second check only guards the case where the flag
    /// is lost but the store is not — a reinstall over an existing container — where
    /// seeding again would duplicate groups the user already arranged.
    ///
    /// > **Seed hazard.** That second check counts **this half's groups only** (SPEC
    /// > §13.5). Counting every group, as the strength seed once did, would read an
    /// > existing install's strength groups as an endurance seed and leave it with none.
    static func seedIfNeeded(
        _ half: Half = .strength,
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        let key = seededKey(for: half)
        guard !defaults.bool(forKey: key) else { return }

        // A store that already holds this half's groups counts as seeded, whatever the
        // flag says. On the error path it counts as seeded too: a fetch that failed is no
        // reason to write rows into a store that may already have them.
        let raw = half.rawValue
        let existing = (try? context.fetchCount(FetchDescriptor<ExerciseGroup>(
            predicate: #Predicate { $0.half == raw }
        ))) ?? 1
        guard existing == 0 else {
            defaults.set(true, forKey: key)
            return
        }

        for (sortIndex, name) in names(for: half).enumerated() {
            context.insert(ExerciseGroup(name: name, sortIndex: sortIndex, half: half))
        }
        // The flag follows the save rather than leading it, so a seed that never reached
        // the disk is tried again next launch instead of being lost silently.
        guard (try? context.save()) != nil else { return }
        defaults.set(true, forKey: key)
    }
}
