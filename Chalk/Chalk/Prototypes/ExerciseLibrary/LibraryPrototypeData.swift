// PROTOTYPE — throwaway. Answers https://github.com/hermanno3005/Chalk/issues/8
// "Three variants of the exercise library screen — the app's home screen and the
//  path to every log — switchable from a floating bottom bar, over four library
//  sizes so 'what does this look like empty, and at 42 exercises?' is one tap away."
//
// No SwiftData, no persistence. Everything resets on relaunch.

import Foundation

/// One entry in the library. Gym-bound exercises carry machines (a Gym plus a
/// manufacturer label), per https://github.com/hermanno3005/Chalk/issues/2
struct ProtoExercise: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var isGymBound: Bool
    var machines: [ProtoMachine] = []
    var records: [ProtoRecord] = []
    /// Round two. Nil means Ungrouped — nothing is asked at create time, you drag
    /// a tile into a group later. Groups are your own buckets, not a taxonomy:
    /// "Compound" sitting next to "Legs" is incoherent as a classification and
    /// entirely fine as a shelf.
    var group: String? = nil

    /// Monotonic backfill again, but only enough of it for a list row.
    func best(at reps: Int) -> Double? {
        records.filter { $0.reps >= reps }.map(\.weight).max()
    }

    /// The row subtitle: what you last did, which is what you want to beat.
    var lastRecord: ProtoRecord? { records.max(by: { $0.date < $1.date }) }

    var lastDate: Date? { lastRecord?.date }

    /// "5 × 55 kg · 3d ago", or nil when the exercise has never been logged.
    var summary: String? {
        guard let last = lastRecord else { return nil }
        return "\(last.reps) × \(last.weight.kg) kg · \(last.date.proAgo)"
    }

    var initial: String { String(name.prefix(1)).uppercased() }
}

/// The sample library sizes the ticket asks about. Cycled from the switcher.
enum LibrarySize: String, CaseIterable {
    case empty, three, medium, full

    var name: String {
        switch self {
        case .empty: "0 exercises"
        case .three: "3 exercises"
        case .medium: "18 exercises"
        case .full: "42 exercises"
        }
    }

    var count: Int {
        switch self {
        case .empty: 0
        case .three: 3
        case .medium: 18
        case .full: 42
        }
    }
}

@Observable
final class LibraryStore {
    var exercises: [ProtoExercise] = []
    var size: LibrarySize = .medium
    var currentGym = "PureGym Islington"

    /// Ordered, renameable, user-owned. Shipped as a suggestion, not a schema.
    var groups: [String] = ["Compound", "Legs", "Push", "Pull", "Core"]

    func exercises(in group: String) -> [ProtoExercise] { groupedCache[group] ?? [] }

    /// The whole point of round two: assignment happens by dragging, after the fact.
    func assign(_ exerciseName: String, to group: String?) {
        guard let index = exercises.firstIndex(where: { $0.name == exerciseName }) else { return }
        exercises[index].group = group
        refreshCaches()
    }

    func moveGroup(from source: IndexSet, to destination: Int) {
        groups.move(fromOffsets: source, toOffset: destination)
    }

    /// Every gym the library knows about — the sticky current gym picks from these.
    var gyms: [String] { Array(Set(exercises.flatMap { $0.machines.map(\.gym) })).sorted() }

    // MARK: - Slices the variants organise by

    // Round three. These were computed properties, so every section re-sorted the
    // whole library on every render — and because `dropTarget` is @Observable state,
    // a drag re-rendered the screen continuously. Six groups x 42 exercises x every
    // frame of a drag is why the screen felt slow. They are caches now, refreshed on
    // mutation.
    private(set) var alphabetical: [ProtoExercise] = []
    private(set) var byRecency: [ProtoExercise] = []
    private var groupedCache: [String: [ProtoExercise]] = [:]
    private(set) var ungrouped: [ProtoExercise] = []

    func refreshCaches() {
        alphabetical = exercises.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        byRecency = exercises.sorted { ($0.lastDate ?? .distantPast) > ($1.lastDate ?? .distantPast) }
        groupedCache = Dictionary(grouping: byRecency.filter { $0.group != nil },
                                  by: { $0.group ?? "" })
        ungrouped = byRecency.filter { $0.group == nil }
    }

    /// Logged in the last 24h — the "you're mid-session" bucket.
    var today: [ProtoExercise] {
        byRecency.filter { ($0.lastDate ?? .distantPast) > .now.addingTimeInterval(-86_400) }
    }

    /// Logged in the last week, excluding today's.
    var thisWeek: [ProtoExercise] {
        byRecency.filter {
            let date = $0.lastDate ?? .distantPast
            return date <= .now.addingTimeInterval(-86_400) && date > .now.addingTimeInterval(-7 * 86_400)
        }
    }

    var everythingElse: [ProtoExercise] {
        let recent = Set(today.map(\.id)).union(thisWeek.map(\.id))
        return alphabetical.filter { !recent.contains($0.id) }
    }

    /// Alphabetical, grouped by first letter — for the sectioned list with an index.
    var sections: [(letter: String, exercises: [ProtoExercise])] {
        Dictionary(grouping: alphabetical, by: \.initial)
            .sorted { $0.key < $1.key }
            .map { (letter: $0.key, exercises: $0.value) }
    }

    /// The single most recent entry across the whole library — the "log it again" seed.
    var lastLogged: ProtoExercise? { byRecency.first.flatMap { $0.lastDate == nil ? nil : $0 } }

    func matching(_ query: String) -> [ProtoExercise] {
        guard !query.isEmpty else { return alphabetical }
        return alphabetical.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Mutations (stubs — the prototype is read-mostly)

    func add(name: String, isGymBound: Bool, gym: String, machineLabel: String) {
        var exercise = ProtoExercise(name: name, isGymBound: isGymBound)
        if isGymBound {
            exercise.machines = [ProtoMachine(gym: gym, label: machineLabel.isEmpty ? "Unbranded" : machineLabel)]
        }
        exercises.append(exercise)
        refreshCaches()
    }

    func delete(_ exercise: ProtoExercise) {
        exercises.removeAll { $0.id == exercise.id }
        refreshCaches()
    }

    func rename(_ exercise: ProtoExercise, to name: String) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        exercises[index].name = name
        refreshCaches()
    }

    /// Appends a record straight from the library screen — variants B and C log
    /// without ever opening the detail screen.
    func log(_ exercise: ProtoExercise, reps: Int, weight: Double) {
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        let machineID = exercises[index].isGymBound
            ? exercises[index].machines.first(where: { $0.gym == currentGym })?.id
                ?? exercises[index].machines.first?.id
            : nil
        exercises[index].records.append(
            ProtoRecord(reps: reps, weight: weight, date: .now, machineID: machineID))
        refreshCaches()
    }

    /// Bridges a library row into the *winning* detail screen from
    /// https://github.com/hermanno3005/Chalk/issues/7, so the library is judged
    /// with the real destination attached rather than a dead end.
    func detailStore(for exercise: ProtoExercise) -> ProtoStore {
        let store = ProtoStore()
        store.exerciseName = exercise.name
        store.isGymBound = exercise.isGymBound
        store.records = exercise.records
        store.machines = exercise.machines
        store.currentMachineID = exercise.machines.first(where: { $0.gym == currentGym })?.id
            ?? exercise.machines.first?.id
        return store
    }

    // MARK: - Sample data

    func load(_ size: LibrarySize) {
        self.size = size
        exercises = Self.sample(count: size.count)
        refreshCaches()
    }

    /// A realistic library: free weights, barbell work, and machines that only exist
    /// at one gym. Names are ordered so the first three read as a starter library.
    private static let catalogue: [(String, Bool)] = [
        ("Bench Press", false), ("Squat", false), ("Deadlift", false),
        ("Overhead Press", false), ("Barbell Row", false), ("Pull-up", false),
        ("Chest Press", true), ("Lat Pulldown", true), ("Leg Press", true),
        ("Dumbbell Curl", false), ("Tricep Pushdown", true), ("Leg Extension", true),
        ("Hamstring Curl", true), ("Cable Fly", true), ("Lateral Raise", false),
        ("Incline Bench Press", false), ("Romanian Deadlift", false), ("Face Pull", true),
        ("Hip Thrust", false), ("Seated Row", true), ("Front Squat", false),
        ("Dip", false), ("Hammer Curl", false), ("Calf Raise", true),
        ("Shrug", false), ("Preacher Curl", true), ("Skull Crusher", false),
        ("Pendlay Row", false), ("Bulgarian Split Squat", false), ("Good Morning", false),
        ("Chin-up", false), ("Close-grip Bench Press", false), ("Arnold Press", false),
        ("Rear Delt Fly", true), ("Pec Deck", true), ("Ab Wheel", false),
        ("Hanging Leg Raise", false), ("Farmer's Walk", false), ("Landmine Press", false),
        ("Cable Crunch", true), ("Reverse Curl", false), ("Zercher Squat", false),
    ]

    /// Pre-assigned so the grouped screens have something to show. Deliberately
    /// incomplete — the exercises missing here land in Ungrouped, which is the
    /// state the design has to survive.
    private static let defaultGroups: [String: String] = [
        "Squat": "Compound", "Deadlift": "Compound", "Bench Press": "Compound",
        "Overhead Press": "Compound", "Pull-up": "Compound", "Barbell Row": "Compound",
        "Front Squat": "Compound", "Romanian Deadlift": "Compound", "Dip": "Compound",
        "Leg Press": "Legs", "Leg Extension": "Legs", "Hamstring Curl": "Legs",
        "Hip Thrust": "Legs", "Bulgarian Split Squat": "Legs",
        "Chest Press": "Push", "Cable Fly": "Push",
        "Tricep Pushdown": "Push", "Incline Bench Press": "Push", "Skull Crusher": "Push",
        "Arnold Press": "Push", "Pec Deck": "Push",
        "Lat Pulldown": "Pull", "Seated Row": "Pull",
        "Dumbbell Curl": "Pull", "Hammer Curl": "Pull", "Chin-up": "Pull",
        "Preacher Curl": "Pull",
        "Ab Wheel": "Core", "Hanging Leg Raise": "Core", "Cable Crunch": "Core",
    ]

    private static let gymNames = ["PureGym Islington", "The Gym Old Street", "Basement Fitness"]
    private static let brands = ["Hammer Strength", "Technogym", "Cybex", "Unbranded"]

    private static func sample(count: Int) -> [ProtoExercise] {
        let day = 86_400.0
        return catalogue.prefix(count).enumerated().map { index, entry in
            var exercise = ProtoExercise(name: entry.0, isGymBound: entry.1)
            exercise.group = defaultGroups[entry.0]
            if entry.1 {
                // One or two machines — most exercises live at your usual gym only.
                let machineCount = index % 3 == 0 ? 2 : 1
                exercise.machines = (0..<machineCount).map { offset in
                    ProtoMachine(gym: gymNames[(index + offset) % gymNames.count],
                                 label: brands[(index + offset) % brands.count])
                }
            }
            // Recency spreads out: a couple logged today, some this week, a long tail
            // that has not been touched in months — including a few never logged at all.
            let untouched = index % 11 == 7
            guard !untouched else { return exercise }
            let recencyDays: Double = switch index {
            case 0...1: 0.2
            case 2...4: Double(index) - 1
            case 5...9: Double(index) * 2
            default: Double(index) * 9
            }
            let recordCount = max(1, 7 - index / 6)
            exercise.records = (0..<recordCount).map { offset in
                // Rotate the rep pattern per exercise, or every row's subtitle
                // reads "5 x ..." and the list looks synthetic.
                let reps = [5, 8, 3, 10, 6, 1, 12][(offset + index) % 7]
                let base = 72.0 - Double(reps) * 2.4 - Double(index) * 0.8
                return ProtoRecord(
                    reps: reps,
                    weight: max(5, base - Double(offset) * 1.6).rounded(toNearest: 2.5),
                    date: .now.addingTimeInterval(-(recencyDays + Double(offset) * 6) * day),
                    machineID: exercise.machines.first?.id)
            }
            return exercise
        }
    }
}
