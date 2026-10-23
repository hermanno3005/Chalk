import Foundation
import SwiftData

/// A **restore** (ADR-0010): a backup read, checked and counted, waiting to replace
/// everything Chalk holds. A replace, never a merge: entries, exercises, ergs, groups,
/// gyms, machines, goals and zones all come from the file, and nothing else survives.
///
/// **Everything is decided before anything is touched.** Making a `Restore` decodes and
/// checks the whole file, so a file Chalk can't restore exactly is refused here, with
/// nothing written. Only `replace()` writes, and it is all or nothing.
///
/// The mechanics follow §5 of *How does a Chalk library round-trip exactly through a
/// readable backup file?* (https://github.com/hermanno3005/Chalk/issues/128).
struct Restore {

    /// The file, decoded and checked.
    let backup: Backup

    /// What the library holds now, counted from the store as it stands.
    private let libraryCounts: Counts
    /// Whether the restore unsets zones this device holds.
    private let clearsZones: Bool
    private let container: ModelContainer
    private let defaults: UserDefaults

    /// Reads `data` as a backup to restore over everything `container` and `defaults`
    /// hold. Throws a `Backup.Refusal` for a file Chalk can't restore, and writes nothing.
    init(reading data: Data, over container: ModelContainer, defaults: UserDefaults) throws {
        backup = try Backup(decoding: data)
        libraryCounts = try Counts(ModelContext(container))
        clearsZones = backup.settings.heartRateZones == nil && HeartRateZones(defaults: defaults) != nil
        self.container = container
        self.defaults = defaults
    }

    /// What a restore over a library that is not empty first says, or `nil` when the
    /// library is empty and it just restores (SPEC §15.1):
    /// `This replaces 1,240 entries with 980 from 12 Mar 2026`.
    ///
    /// **Each side is counted by what it holds**, and the date is the file's own `madeAt`,
    /// never the file's metadata, which neither AirDrop nor a copy keeps reliably. Zones
    /// the restore unsets are named; changed boundaries are not.
    func confirmation(locale: Locale = .current, timeZone: TimeZone = .current) -> String? {
        guard !libraryCounts.isEmpty else { return nil }
        let backupCounts = Counts(backup)
        // `…1,240 entries with 980…`: the second side's noun goes when both count entries.
        let backupSide = libraryCounts.entries > 0 && backupCounts.entries > 0
            ? backupCounts.entries.formatted(.number.locale(locale))
            : backupCounts.description(locale: locale)
        let date = backup.madeAt.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).day().month(.abbreviated).year())
        let zones = clearsZones ? ", and clears your heart-rate zones" : ""
        return "This replaces \(libraryCounts.description(locale: locale)) with \(backupSide) from \(date)\(zones)"
    }

    /// Replaces everything with the backup.
    ///
    /// **One fresh context, one `save()`**: every row of all five entities is deleted and
    /// the backup's graph inserted in the same SQLite transaction, so a failure anywhere
    /// before the commit leaves the store exactly as it was. Two traps, both seen on iOS
    /// 18.5 against Apple's docs: a new context comes up autosaving, which could commit
    /// an empty library between the deletes and the inserts, and `delete(model:where:)`
    /// commits at once as a batch delete that `rollback()` does not undo, so it is never
    /// used here.
    ///
    /// The zones are written only after the store commits, since `UserDefaults` can't join
    /// the transaction and can't fail. Both seed flags are set, so the first-launch seed
    /// never adds its suggested groups on top of a restored library.
    ///
    /// `beforeSave` runs after the deletes and inserts and before the commit. It is there
    /// for a test to prove that a failure at that point changes nothing.
    func replace(beforeSave: () throws -> Void = {}) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            try deleteEverything(in: context)
            insertBackup(into: context)
            try beforeSave()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        if let lowerBounds = backup.settings.heartRateZones, let zones = HeartRateZones(lowerBounds: lowerBounds) {
            zones.save(to: defaults)
        } else {
            HeartRateZones.clear(from: defaults)
        }
        for half in Half.allCases {
            defaults.set(true, forKey: SuggestedGroups.seededKey(for: half))
        }
    }

    /// Deletes every row, one by one, the orphans that hang off nothing included, so what
    /// is left is exactly the file.
    private func deleteEverything(in context: ModelContext) throws {
        for entry in try context.fetch(FetchDescriptor<Entry>()) { context.delete(entry) }
        for machine in try context.fetch(FetchDescriptor<Machine>()) { context.delete(machine) }
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) { context.delete(exercise) }
        for group in try context.fetch(FetchDescriptor<ExerciseGroup>()) { context.delete(group) }
        for gym in try context.fetch(FetchDescriptor<Gym>()) { context.delete(gym) }
    }

    /// Inserts the backup's graph: groups and gyms first, then each exercise with its
    /// machines and the entries under each.
    private func insertBackup(into context: ModelContext) {
        var groups: [UUID: ExerciseGroup] = [:]
        for row in backup.groups {
            let group = ExerciseGroup(id: row.id, name: row.name, sortIndex: row.sortIndex)
            group.half = row.half
            context.insert(group)
            groups[row.id] = group
        }
        var gyms: [UUID: Gym] = [:]
        for row in backup.gyms {
            let gym = Gym(id: row.id, name: row.name, isArchived: row.isArchived)
            context.insert(gym)
            gyms[row.id] = gym
        }
        for row in backup.exercises {
            let exercise = Exercise(id: row.id, name: row.name, group: row.group.flatMap { groups[$0] })
            exercise.kind = row.kind
            exercise.unit = row.unit
            row.goal.write(to: exercise)
            context.insert(exercise)
            for entry in row.entries {
                context.insert(entry.model(on: exercise, machine: nil))
            }
            for machineRow in row.machines {
                let machine = Machine(
                    id: machineRow.id,
                    manufacturer: machineRow.manufacturer,
                    label: machineRow.label,
                    exercise: exercise,
                    gym: machineRow.gym.flatMap { gyms[$0] }
                )
                machineRow.goal.write(to: machine)
                context.insert(machine)
                for entry in machineRow.entries {
                    context.insert(entry.model(on: exercise, machine: machine))
                }
            }
        }
    }
}

/// What one side of a restore holds, as its confirmation counts it.
private struct Counts {
    var entries = 0
    var exercises = 0
    var ergs = 0
    var gyms = 0

    /// **A library is empty when it holds no exercise, no erg and no gym** (SPEC §15.1).
    /// Groups, zones and units don't count, since a fresh install already holds its
    /// seeded groups.
    var isEmpty: Bool { exercises + ergs + gyms == 0 }

    /// The library `context` reads. An entry with no exercise is never counted
    /// (invariant 2).
    init(_ context: ModelContext) throws {
        entries = try context.fetchCount(FetchDescriptor<Entry>(predicate: #Predicate { $0.exercise != nil }))
        ergs = try context.fetchCount(FetchDescriptor<Exercise>(predicate: #Predicate { $0.unit != nil }))
        exercises = try context.fetchCount(FetchDescriptor<Exercise>()) - ergs
        gyms = try context.fetchCount(FetchDescriptor<Gym>())
    }

    init(_ backup: Backup) {
        entries = backup.exercises.reduce(0) { $0 + $1.allEntries.count }
        ergs = backup.exercises.count { $0.unit != nil }
        exercises = backup.exercises.count - ergs
        gyms = backup.gyms.count
    }

    /// Its entries when it has any, otherwise its exercises, ergs and gyms, otherwise
    /// *nothing*: `1,240 entries`, `3 exercises and 1 gym`, `nothing`.
    func description(locale: Locale) -> String {
        func counted(_ count: Int, _ one: String, _ many: String) -> String? {
            count == 0 ? nil : "\(count.formatted(.number.locale(locale))) \(count == 1 ? one : many)"
        }
        if let entries = counted(entries, "entry", "entries") { return entries }
        let parts = [counted(exercises, "exercise", "exercises"), counted(ergs, "erg", "ergs"), counted(gyms, "gym", "gyms")]
            .compactMap(\.self)
        guard let last = parts.last else { return "nothing" }
        return parts.count == 1 ? last : parts.dropLast().joined(separator: ", ") + " and " + last
    }
}

private extension Backup.GoalFields {

    func write(to exercise: Exercise) {
        exercise.goalReps = goalReps
        exercise.goalWeight = goalWeight
        exercise.goalSetAt = goalSetAt
        exercise.goalZone = goalZone
        exercise.goalDuration = goalDuration
        exercise.goalIntensity = goalIntensity
        exercise.goalIncline = goalIncline
    }

    func write(to machine: Machine) {
        machine.goalReps = goalReps
        machine.goalWeight = goalWeight
        machine.goalSetAt = goalSetAt
        machine.goalZone = goalZone
        machine.goalDuration = goalDuration
        machine.goalIntensity = goalIntensity
        machine.goalIncline = goalIncline
    }
}

private extension Backup.Entry {

    func model(on exercise: Exercise, machine: Machine?) -> Entry {
        Entry(
            id: id,
            reps: reps,
            weight: weight,
            duration: duration,
            intensity: intensity,
            incline: incline,
            averageHeartRate: averageHeartRate,
            peakHeartRate: peakHeartRate,
            date: date,
            exercise: exercise,
            machine: machine
        )
    }
}
