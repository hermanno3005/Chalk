import Foundation
import SwiftData

/// A **convert** (SPEC §15.2, ADR-0009): a unit change that rewrites every stored number
/// on its scale onto the new one, goals included, counted and waiting on its confirmation.
///
/// A weight convert rewrites every lift's weight and the strength goal at both scopes; a
/// distance convert rewrites every speed erg's intensity and its speed goal at both scopes.
/// Each rounds on the convert grid (`WeightUnit.onConvertGrid(_:)`), never the stepper
/// grid. Reps, durations, incline, watts, splits, levels, heart rates, zones and every
/// `goalSetAt` are untouched, and a goal's origin and reached state follow, since they are
/// derived. **It is one-way**: a backup is how you take it back (ADR-0010).
struct Convert {

    let change: UnitChange
    /// How many entries it rewrites: every lift, or every speed erg's interval.
    let entryCount: Int
    /// How many goals it rewrites, at both scopes.
    let goalCount: Int
    private let container: ModelContainer
    private let defaults: UserDefaults

    /// Counts what `change` would rewrite in the store as it stands.
    init(_ change: UnitChange, over container: ModelContainer, defaults: UserDefaults) throws {
        self.change = change
        self.container = container
        self.defaults = defaults
        (entryCount, goalCount) = try change.written(in: ModelContext(container))
    }

    /// What the confirmation says, with a count of each side it rewrites and the grid it
    /// rounds to: `Converts 1,240 entries and 6 goals to lb, rounded to the nearest pound.`
    /// A side with nothing on it is left out.
    func confirmation(locale: Locale = .current) -> String {
        let counts = [
            entryCount == 0 ? nil : String(localized: "\(entryCount) entries", locale: locale),
            goalCount == 0 ? nil : String(localized: "\(goalCount) goals", locale: locale),
        ].compactMap(\.self)
        return String(localized: "Converts \(listed(counts) ?? "") to \(change.symbol), rounded to \(change.convertGrid). This can't be undone, except by restoring a backup.")
    }

    /// Rewrites every number on the scale, then moves the scale.
    ///
    /// **One fresh context, one `save()`**, as a restore replaces a library: a failure
    /// anywhere before the commit leaves every number as it was. The unit is written only
    /// after the store commits, since `UserDefaults` can't join the transaction.
    ///
    /// `beforeSave` runs after the rewrite and before the commit. It is there for a test to
    /// prove that a failure at that point changes nothing.
    func convert(beforeSave: () throws -> Void = {}) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            try rewrite(in: context)
            try beforeSave()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        change.relabel(in: defaults)
    }

    private func rewrite(in context: ModelContext) throws {
        switch change {
        case .weights(let unit):
            let from = WeightUnit(defaults: defaults)
            for entry in try context.fetch(UnitChange.lifts) {
                entry.weight = from.converted(entry.weight, to: unit)
            }
            for exercise in try context.fetch(UnitChange.exercisesWithAWeightGoal) {
                exercise.goalWeight = exercise.goalWeight.map { from.converted($0, to: unit) }
            }
            for machine in try context.fetch(UnitChange.machinesWithAWeightGoal) {
                machine.goalWeight = machine.goalWeight.map { from.converted($0, to: unit) }
            }
        case .distances(let unit):
            let from = DistanceUnit(defaults: defaults)
            for erg in try context.fetch(UnitChange.speedErgs) {
                for entry in erg.entries ?? [] where entry.intensity > 0 {
                    entry.intensity = from.converted(entry.intensity, to: unit)
                }
                erg.goalIntensity = erg.goalIntensity.map { from.converted($0, to: unit) }
                for machine in erg.machines ?? [] {
                    machine.goalIntensity = machine.goalIntensity.map { from.converted($0, to: unit) }
                }
            }
        }
    }
}
