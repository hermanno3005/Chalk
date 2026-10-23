import Foundation
import SwiftData

extension Backup {

    /// Everything `context` holds, and the zones `defaults` holds, as a backup made at
    /// `madeAt`. Reads through the context, so its unsaved edits are included.
    init(of context: ModelContext, defaults: UserDefaults, madeAt: Date = .now) throws {
        try self.init(of: context, settings: Settings(defaults: defaults), madeAt: madeAt)
    }

    /// Everything `context` holds, with `settings`, as a backup made at `madeAt`.
    ///
    /// **Every array is sorted**, so a backup of a restored backup is the same bytes:
    /// groups by half and then order, gyms and exercises by name, machines by id, entries
    /// by date, each tied on id. Nothing derived is written, and neither is a row that
    /// invariant 2 treats as non-existent: an entry or a machine with no exercise.
    init(of context: ModelContext, settings: Settings, madeAt: Date = .now) throws {
        self.madeAt = madeAt
        self.settings = settings
        groups = try context.fetch(FetchDescriptor<ExerciseGroup>())
            .map(Group.init)
            .sorted { ($0.half, $0.sortIndex, $0.id.uuidString) < ($1.half, $1.sortIndex, $1.id.uuidString) }
        gyms = try context.fetch(FetchDescriptor<Chalk.Gym>())
            .map(Gym.init)
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
        exercises = try context.fetch(FetchDescriptor<Chalk.Exercise>())
            .map(Exercise.init)
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }
}

extension Backup.Settings {

    /// The settings `defaults` holds that are part of the record.
    init(defaults: UserDefaults) {
        self.init(
            heartRateZones: HeartRateZones(defaults: defaults)?.lowerBounds,
            weightUnit: WeightUnit(defaults: defaults)
        )
    }
}

private extension Backup.Group {
    init(_ group: ExerciseGroup) {
        self.init(id: group.id, name: group.name, sortIndex: group.sortIndex, half: group.half)
    }
}

private extension Backup.Gym {
    init(_ gym: Chalk.Gym) {
        self.init(id: gym.id, name: gym.name, isArchived: gym.isArchived)
    }
}

private extension Backup.Exercise {
    init(_ exercise: Chalk.Exercise) {
        self.init(
            id: exercise.id,
            name: exercise.name,
            kind: exercise.kind,
            unit: exercise.unit,
            group: exercise.group?.id,
            goal: Backup.GoalFields(
                goalReps: exercise.goalReps,
                goalWeight: exercise.goalWeight,
                goalSetAt: exercise.goalSetAt,
                goalZone: exercise.goalZone,
                goalDuration: exercise.goalDuration,
                goalIntensity: exercise.goalIntensity,
                goalIncline: exercise.goalIncline
            ),
            machines: (exercise.machines ?? [])
                .map(Backup.Machine.init)
                .sorted { $0.id.uuidString < $1.id.uuidString },
            entries: Backup.Entry.sorted((exercise.entries ?? []).filter { $0.machine == nil })
        )
    }
}

private extension Backup.Machine {
    init(_ machine: Chalk.Machine) {
        self.init(
            id: machine.id,
            manufacturer: machine.manufacturer,
            label: machine.label,
            gym: machine.gym?.id,
            goal: Backup.GoalFields(
                goalReps: machine.goalReps,
                goalWeight: machine.goalWeight,
                goalSetAt: machine.goalSetAt,
                goalZone: machine.goalZone,
                goalDuration: machine.goalDuration,
                goalIntensity: machine.goalIntensity,
                goalIncline: machine.goalIncline
            ),
            entries: Backup.Entry.sorted(machine.entries ?? [])
        )
    }
}

private extension Backup.Entry {
    init(_ entry: Chalk.Entry) {
        self.init(
            id: entry.id,
            reps: entry.reps,
            weight: entry.weight,
            duration: entry.duration,
            intensity: entry.intensity,
            incline: entry.incline,
            averageHeartRate: entry.averageHeartRate,
            peakHeartRate: entry.peakHeartRate,
            date: entry.date
        )
    }

    /// `entries` as the file lists them: by date, tied on id.
    static func sorted(_ entries: [Chalk.Entry]) -> [Backup.Entry] {
        entries
            .map(Backup.Entry.init)
            .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
    }
}
