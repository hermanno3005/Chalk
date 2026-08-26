import Foundation
import SwiftData

/// The five groups Chalk ships with, seeded on first launch (SPEC §7.2).
///
/// A **suggestion**, and nothing more: once seeded they are ordinary rows — renameable,
/// reorderable, deletable — and no screen ever falls back to this list. Which is why the
/// seed happens once and never again: restoring a group the user deleted would make the
/// suggestion a schema.
enum SuggestedGroups {

    /// `Compound` beside `Legs` is incoherent as a classification and entirely fine as a
    /// shelf you arranged yourself. The order is the order they seed in.
    static let names = ["Compound", "Legs", "Push", "Pull", "Core"]

    /// Set once the seed has run. It lives in `UserDefaults` rather than the store
    /// because it is not part of the record — the store holds lifting, and adding a
    /// sixth entity to hold one boolean would put it in every CloudKit mirror later.
    static let seededKey = "com.hermannaust.Chalk.suggestedGroupsSeeded"

    /// Seeds the five groups if this install has never seeded them.
    ///
    /// The flag is the real gate; the second check only guards the case where the flag
    /// is lost but the store is not — a reinstall over an existing container — where
    /// seeding again would duplicate groups the user already arranged.
    static func seedIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: seededKey) else { return }

        // A store that already holds groups counts as seeded, whatever the flag says.
        // On the error path it counts as seeded too: a fetch that failed is no reason to
        // write five rows into a store that may already have them.
        let existing = (try? context.fetchCount(FetchDescriptor<ExerciseGroup>())) ?? 1
        guard existing == 0 else {
            defaults.set(true, forKey: seededKey)
            return
        }

        for (sortIndex, name) in names.enumerated() {
            context.insert(ExerciseGroup(name: name, sortIndex: sortIndex))
        }
        // The flag follows the save rather than leading it, so a seed that never reached
        // the disk is tried again next launch instead of being lost silently.
        guard (try? context.save()) != nil else { return }
        defaults.set(true, forKey: seededKey)
    }
}
