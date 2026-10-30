#if DEBUG
import Foundation
import SwiftData

/// The library the App Store screenshots are taken over (SPEC §15.6): half a year of
/// lifting and erg training, believable at a glance, with a goal still out of reach on
/// Bench Press and on the treadmill. `scripts/screenshots` takes them.
///
/// **Debug builds only, and only when asked.** Launched with `-screenshots.library YES`,
/// Chalk restores this library over everything it holds before it opens, so never pass it
/// to a build on the phone. `-screenshots.open <name>` then opens that exercise or erg as
/// a Spotlight result would.
///
/// Every number is worked out from the day it is made, never random, so a retake shows
/// the same library with `today` still today.
enum ScreenshotLibrary {

    /// Restores the library and opens what was asked for, if the launch asked.
    static func restoreIfAsked(defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: "screenshots.library"),
              case .opened(let container) = ChalkStore.open()
        else { return }
        let backup = backup()
        do {
            try Restore(reading: try backup.encoded(), over: container, defaults: defaults).replace()
        } catch {
            fatalError("The screenshot library didn't restore: \(error)")
        }
        // Standing in the gym the gym-bound numbers were logged at, so they show.
        let context = ModelContext(container)
        let gyms = GymsModel(context: context, defaults: defaults)
        gyms.select(gyms.gyms.first)
    }

    /// Opens the exercise or erg `-screenshots.open` names on its detail screen.
    static func openIfAsked(in context: ModelContext, library: LibraryModel, defaults: UserDefaults = .standard) {
        guard let name = defaults.string(forKey: "screenshots.open"),
              let exercise = try? context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })).first
        else { return }
        library.open(exerciseWithID: exercise.id)
    }

    // MARK: - The library

    /// The four lower bounds of Z2 to Z5.
    static let zones = [128, 145, 158, 170]

    /// The library as a backup, made `now`.
    static func backup(now: Date = .now, calendar: Calendar = .current) -> Backup {
        let days = Days(now: now, calendar: calendar)
        var ids = IDs()
        let gym = Backup.Gym(id: ids.next(), name: "Riverside", isArchived: false)

        let strength = ["Compound", "Legs", "Push", "Pull"].enumerated().map {
            Backup.Group(id: ids.next(), name: $1, sortIndex: $0, half: Half.strength.rawValue)
        }
        let endurance = ["Treadmills", "Rowing & Ski", "Bikes"].enumerated().map {
            Backup.Group(id: ids.next(), name: $1, sortIndex: $0, half: Half.endurance.rawValue)
        }

        let lifts = [
            Lift("Bench Press", strength[0], from: 92, to: 104, offset: 0),
            Lift("Back Squat", strength[0], from: 120, to: 136, offset: 1),
            Lift("Deadlift", strength[0], from: 150, to: 167, offset: 2),
            Lift("Overhead Press", strength[0], from: 55, to: 62, offset: 3),
            Lift("Romanian Deadlift", strength[1], from: 110, to: 122, offset: 3),
            Lift("Leg Press", strength[1], from: 200, to: 232, offset: 1, machine: "Plate-loaded"),
            Lift("Leg Curl", strength[1], from: 55, to: 63, offset: 2, machine: "Seated"),
            Lift("Incline Dumbbell Press", strength[2], from: 34, to: 39, offset: 2),
            Lift("Chest Press", strength[2], from: 80, to: 91, offset: 0, machine: "Plate-loaded"),
            Lift("Barbell Row", strength[3], from: 85, to: 96, offset: 1),
            Lift("Lat Pulldown", strength[3], from: 70, to: 81, offset: 3, machine: "Cable stack"),
            Lift("Seated Cable Row", strength[3], from: 70, to: 79, offset: 0, machine: "Cable stack"),
        ]
        var exercises = lifts.map { $0.exercise(at: gym, days: days, ids: &ids) }
        // Bench Press's goal: 5 × 92.5 kg, set six weeks ago and not reached yet.
        exercises[0].goal = Backup.GoalFields(goalReps: 5, goalWeight: 92.5, goalSetAt: days.date(42, minute: 0))

        exercises += [
            Erg.treadmill(group: endurance[0], gym: gym, days: days, ids: &ids),
            Erg.rower(group: endurance[1], days: days, ids: &ids),
            Erg.bike("Bike", group: endurance[2], every: 6, offset: 3, from: 170, to: 188, days: days, ids: &ids),
            Erg.bike("Air Bike", group: endurance[2], every: 9, offset: 4, from: 240, to: 262, days: days, ids: &ids),
        ]

        return Backup(
            madeAt: now,
            settings: Backup.Settings(heartRateZones: zones),
            groups: strength + endurance,
            gyms: [gym],
            exercises: exercises
        )
    }

    /// The days the library was trained on, counted back from today: day 0 is today.
    private struct Days {
        let now: Date
        let calendar: Calendar
        /// Half a year.
        let count = 182

        /// When something on day `daysAgo` was logged: an hour and a half ago today,
        /// otherwise the evening of that day, `minute` minutes in.
        func date(_ daysAgo: Int, minute: Int) -> Date {
            if daysAgo == 0 { return now.addingTimeInterval(Double(minute - 90) * 60) }
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
            return day.addingTimeInterval(Double(18 * 60 + minute) * 60)
        }

        /// How far through the half year `daysAgo` is, from 0 at its start to 1 today.
        func progress(_ daysAgo: Int) -> Double {
            1 - Double(daysAgo) / Double(count)
        }
    }

    /// UUIDs that are the same on every retake.
    private struct IDs {
        private var last = 0

        mutating func next() -> UUID {
            last += 1
            return UUID(uuidString: String(format: "00000000-0000-4000-8000-%012X", last))!
        }
    }

    /// A lift trained about twice a week, a heavy and a lighter entry each time, its
    /// one-rep strength rising from `from` to `to` kg over the half year.
    private struct Lift {
        let name: String
        let group: Backup.Group
        let from: Double
        let to: Double
        /// Which of every four days it is trained on.
        let offset: Int
        /// The machine's label when it is gym-bound.
        let machine: String?

        init(_ name: String, _ group: Backup.Group, from: Double, to: Double, offset: Int, machine: String? = nil) {
            self.name = name
            self.group = group
            self.from = from
            self.to = to
            self.offset = offset
            self.machine = machine
        }

        /// Every rep count from 1 to 12 comes round, so the whole curve is proven.
        private static let reps = [5, 8, 3, 10, 6, 12, 2, 8, 4, 5, 1, 10, 7, 9, 11, 6]

        func exercise(at gym: Backup.Gym, days: Days, ids: inout IDs) -> Backup.Exercise {
            var entries: [Backup.Entry] = []
            var session = 0
            for daysAgo in stride(from: days.count, through: 0, by: -1) where (daysAgo + offset) % 4 == 0 {
                let strength = from + (to - from) * days.progress(daysAgo)
                // Each lift starts the rep counts at a place of its own.
                let start = session + offset * 5
                for (set, index) in [start, start + 7].enumerated() {
                    let reps = Self.reps[index % Self.reps.count]
                    // Epley, backed off a little more on some days than others.
                    let effort = 0.9 + 0.025 * Double((session * 7 + set * 3) % 4)
                    let weight = (strength / (1 + Double(reps) / 30) * effort / 2.5).rounded() * 2.5
                    entries.append(Backup.Entry(
                        id: ids.next(),
                        reps: reps,
                        weight: weight,
                        duration: 0,
                        intensity: 0,
                        incline: 0,
                        averageHeartRate: 0,
                        peakHeartRate: 0,
                        date: days.date(daysAgo, minute: set * 6)
                    ))
                }
                session += 1
            }
            let id = ids.next()
            guard let machine else {
                return Backup.Exercise(id: id, name: name, kind: ExerciseKind.freeWeight.rawValue, group: group.id, goal: .none, machines: [], entries: entries)
            }
            return Backup.Exercise(
                id: id,
                name: name,
                kind: ExerciseKind.gymBound.rawValue,
                group: group.id,
                goal: .none,
                machines: [Backup.Machine(id: ids.next(), label: machine, gym: gym.id, goal: .none, entries: entries)],
                entries: []
            )
        }
    }

    /// The ergs, each trained on a rotation of a long easy piece, threshold intervals and
    /// short hard ones, so every zone has a line.
    private enum Erg {

        /// One interval to do on a visit: how long, in which zone, and how hard a piece
        /// of that length in that zone is, at the start of the half year and today.
        struct Piece {
            let duration: Int
            let zone: Int
            let from: Double
            let to: Double
            var times = 1
        }

        /// A gym-bound treadmill at 1 %, with a goal of 6:00 at 14.6 km/h in Z4.
        static func treadmill(group: Backup.Group, gym: Backup.Gym, days: Days, ids: inout IDs) -> Backup.Exercise {
            let visits: [[Piece]] = [
                [Piece(duration: 600, zone: 2, from: 10.0, to: 10.6), Piece(duration: 360, zone: 4, from: 13.4, to: 14.2, times: 3)],
                [Piece(duration: 1800, zone: 2, from: 9.8, to: 10.4)],
                [Piece(duration: 600, zone: 2, from: 10.0, to: 10.6), Piece(duration: 240, zone: 4, from: 13.9, to: 14.7, times: 4)],
                [Piece(duration: 1200, zone: 3, from: 11.4, to: 12.1), Piece(duration: 60, zone: 5, from: 16.8, to: 17.6, times: 6)],
                [Piece(duration: 2700, zone: 2, from: 9.6, to: 10.2)],
                [Piece(duration: 600, zone: 3, from: 11.8, to: 12.5), Piece(duration: 120, zone: 5, from: 16.0, to: 16.9, times: 4)],
                [Piece(duration: 1200, zone: 2, from: 10.1, to: 10.7)],
                [Piece(duration: 600, zone: 2, from: 10.0, to: 10.6), Piece(duration: 480, zone: 4, from: 13.1, to: 13.8, times: 2)],
                [Piece(duration: 180, zone: 4, from: 14.2, to: 15.0, times: 5), Piece(duration: 180, zone: 5, from: 15.4, to: 16.2)],
            ]
            let entries = Self.entries(visits: visits, every: 4, offset: 3, unit: .speed, incline: 1, days: days, ids: &ids)
            var goal = Backup.GoalFields.none
            goal.goalZone = 4
            goal.goalDuration = 360
            goal.goalIntensity = 14.6
            goal.goalIncline = 1
            goal.goalSetAt = days.date(35, minute: 0)
            return Backup.Exercise(
                id: ids.next(),
                name: "Treadmill",
                kind: ExerciseKind.gymBound.rawValue,
                unit: ErgUnit.speed.rawValue,
                group: group.id,
                goal: .none,
                machines: [Backup.Machine(id: ids.next(), label: "Upstairs", gym: gym.id, goal: goal, entries: entries)],
                entries: []
            )
        }

        /// A transferable rower, in seconds per 500 m.
        static func rower(group: Backup.Group, days: Days, ids: inout IDs) -> Backup.Exercise {
            let visits: [[Piece]] = [
                [Piece(duration: 1800, zone: 2, from: 129, to: 125)],
                [Piece(duration: 240, zone: 4, from: 113, to: 109, times: 4)],
                [Piece(duration: 1200, zone: 3, from: 121, to: 117.5)],
                [Piece(duration: 480, zone: 4, from: 116, to: 112, times: 2)],
                [Piece(duration: 60, zone: 5, from: 103, to: 99.5, times: 6)],
            ]
            return Backup.Exercise(
                id: ids.next(),
                name: "Rower",
                kind: ExerciseKind.freeWeight.rawValue,
                unit: ErgUnit.split.rawValue,
                group: group.id,
                goal: .none,
                machines: [],
                entries: Self.entries(visits: visits, every: 5, offset: 3, unit: .split, incline: 0, days: days, ids: &ids)
            )
        }

        /// A transferable bike in watts, whose Z2 watts rise from `from` to `to`.
        static func bike(_ name: String, group: Backup.Group, every: Int, offset: Int, from: Double, to: Double, days: Days, ids: inout IDs) -> Backup.Exercise {
            let visits: [[Piece]] = [
                [Piece(duration: 2400, zone: 2, from: from, to: to)],
                [Piece(duration: 240, zone: 4, from: from * 1.5, to: to * 1.5, times: 4)],
                [Piece(duration: 60, zone: 5, from: from * 2.4, to: to * 2.4, times: 5)],
            ]
            return Backup.Exercise(
                id: ids.next(),
                name: name,
                kind: ExerciseKind.freeWeight.rawValue,
                unit: ErgUnit.watts.rawValue,
                group: group.id,
                goal: .none,
                machines: [],
                entries: Self.entries(visits: visits, every: every, offset: offset, unit: .watts, incline: 0, days: days, ids: &ids)
            )
        }

        /// One visit every `every` days, taking `visits` in turn, so that the last visit
        /// is the first of them.
        static func entries(visits: [[Piece]], every: Int, offset: Int, unit: ErgUnit, incline: Double, days: Days, ids: inout IDs) -> [Backup.Entry] {
            var entries: [Backup.Entry] = []
            let visitDays = stride(from: days.count, through: 0, by: -1).filter { ($0 + offset) % every == 0 }
            for (visit, daysAgo) in visitDays.enumerated() {
                var minute = 0
                for piece in visits[(visitDays.count - 1 - visit) % visits.count] {
                    for repeat_ in 0..<piece.times {
                        // A little off the trend either way, as no two days feel the same.
                        let wobble = Double((visit * 5 + repeat_ * 3) % 5 - 2) * 0.01
                        let intensity = unit.rounded((piece.from + (piece.to - piece.from) * days.progress(daysAgo)) * (1 + wobble * unit.hardnessSign))
                        let average = heartRate(in: piece.zone, step: visit + repeat_)
                        entries.append(Backup.Entry(
                            id: ids.next(),
                            reps: 0,
                            weight: 0,
                            duration: piece.duration,
                            intensity: intensity,
                            incline: incline,
                            averageHeartRate: average,
                            peakHeartRate: average + 5 + (visit + repeat_) % 5,
                            date: days.date(daysAgo, minute: minute)
                        ))
                        minute += piece.duration / 60 + 2
                    }
                }
            }
            return entries
        }

        /// An average heart rate well inside `zone`.
        static func heartRate(in zone: Int, step: Int) -> Int {
            let floor = ScreenshotLibrary.zones[zone - 2]
            return floor + 3 + step % 6
        }
    }
}

private extension Backup.GoalFields {
    static let none = Backup.GoalFields()
}
#endif
