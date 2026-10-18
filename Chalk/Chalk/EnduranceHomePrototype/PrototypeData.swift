import SwiftData
import SwiftUI

// PROTOTYPE — sample data for #96. In memory only; nothing is stored. The strength half
// is the **real** library over a seeded in-memory store, so each variant is judged
// against the screen it actually has to share the phone with. The endurance half is a
// stub of plain structs: what an erg *is* has been decided, how it is stored has not.

/// Which half of Chalk is on screen. Persisted, so every variant with a toggle reopens on
/// the side you last used — the dev trains strength and endurance on **separate days**.
enum Half: String, CaseIterable {
    case strength = "Strength"
    case endurance = "Endurance"
}

/// What is in the two libraries. The strength library is held at a settled size; the
/// endurance one varies, because its size is what the ticket asks about.
enum ProtoDataset: String, CaseIterable {
    case full = "18 + 9 ergs"
    case three = "18 + 3 ergs"
    case noErgs = "18 + 0 ergs"
    case liftedLast = "9 ergs, lifted last"
    case fresh = "fresh install"

    var strengthCount: Int { self == .fresh ? 0 : 18 }
}

/// One interval, as #94 writes it: `6:00 at 15.0 km/h · 168/174 bpm`.
struct ProtoInterval {
    let duration: String
    let intensity: String
    let average: Int
    let peak: Int
    let date: Date

    /// The tile line — strength's `8 × 52.5 kg · today`, with the heart rate it cost.
    var tileText: String { "\(duration) at \(intensity) · \(Self.day(date))" }
    /// The resume card line: the whole record.
    var cardText: String { "\(duration) at \(intensity) · \(average)/\(peak) bpm · \(Self.day(date))" }

    static func day(_ date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: date),
            to: Calendar.current.startOfDay(for: .now)
        ).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        default: return "\(days) days ago"
        }
    }
}

/// An erg in the endurance library. Gym-bound ergs carry their machines — a model at a
/// gym (#93) — and still draw **one tile**, exactly as a gym-bound exercise does.
struct ProtoErg: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let unit: String
    let machines: [String]
    let last: ProtoInterval?

    var isTransferable: Bool { machines.isEmpty }

    static func == (lhs: ProtoErg, rhs: ProtoErg) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Both libraries for one dataset. Rebuilt whenever the dataset pill changes.
@MainActor
final class ProtoStore {
    let container: ModelContainer
    let strength: LibraryModel
    /// Most recent first — the endurance side orders exactly as strength's tiles do.
    let ergs: [ProtoErg]

    init(dataset: ProtoDataset) {
        container = try! ModelContainer(
            for: Schema(versionedSchema: ChalkSchemaV1.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let defaults = UserDefaults(suiteName: "chalk-prototype-\(UUID().uuidString)")!
        let context = container.mainContext
        SuggestedGroups.seedIfNeeded(in: context, defaults: defaults)
        let ergsLoggedLast = dataset != .liftedLast
        if dataset.strengthCount > 0 {
            Self.seedStrength(in: context, offsetDays: ergsLoggedLast ? 1 : 0)
        }
        strength = LibraryModel(context: context, defaults: defaults)
        if let home = strength.gyms.gyms.first(where: { $0.name == "FitX Mitte" }) {
            strength.gyms.select(home)
        }
        let ergs: [ProtoErg]
        switch dataset {
        case .full, .liftedLast: ergs = Self.nineErgs(offsetDays: ergsLoggedLast ? 0 : 1)
        case .three: ergs = Self.threeErgs
        case .noErgs, .fresh: ergs = []
        }
        self.ergs = ergs.sorted { ($0.last?.date ?? .distantPast) > ($1.last?.date ?? .distantPast) }
    }

    /// The more recent of the two halves' last records — variant D's single resume card.
    var ergWasLast: Bool {
        guard let erg = ergs.first?.last else { return false }
        guard let lift = strength.resume?.lastEntry else { return true }
        return erg.date > lift.date
    }

    private static func daysAgo(_ days: Double, hour: Double = 0) -> Date {
        Date.now.addingTimeInterval(-86_400 * days - 3_600 * hour)
    }

    private static func seedStrength(in context: ModelContext, offsetDays: Double) {
        let groups = (try? context.fetch(FetchDescriptor<ExerciseGroup>())) ?? []
        func group(_ name: String?) -> ExerciseGroup? { groups.first { $0.name == name } }

        let fitx = Gym(name: "FitX Mitte")
        let mcfit = Gym(name: "McFit Ost")
        context.insert(fitx)
        context.insert(mcfit)

        let lifts: [(String, String?, Int, Double)] = [
            ("Squat", "Compound", 5, 100), ("Bench Press", "Compound", 5, 80),
            ("Deadlift", "Compound", 5, 140), ("Overhead Press", "Compound", 6, 50),
            ("Leg Curl", "Legs", 10, 45), ("Bulgarian Split Squat", "Legs", 8, 24),
            ("Calf Raise", "Legs", 12, 60), ("Incline DB Press", "Push", 8, 30),
            ("Dips", "Push", 8, 20), ("Lateral Raise", "Push", 12, 10),
            ("Pull-up", "Pull", 6, 10), ("Barbell Row", "Pull", 8, 70),
            ("Lat Pulldown", "Pull", 10, 60), ("Face Pull", "Pull", 15, 25),
            ("Ab Wheel", "Core", 10, 0.5), ("Hanging Leg Raise", "Core", 10, 0.5),
            ("Hip Thrust", nil, 8, 100),
        ]
        for (index, lift) in lifts.enumerated() {
            let exercise = Exercise(name: lift.0, group: group(lift.1))
            context.insert(exercise)
            context.insert(Entry(
                reps: lift.2,
                weight: lift.3,
                date: daysAgo(offsetDays + Double(index / 4) * 2, hour: Double(index % 4)),
                exercise: exercise
            ))
        }
        // One gym-bound exercise, so the Gym menu has something to say.
        let legPress = Exercise(name: "Leg Press", kind: .gymBound, group: group("Legs"))
        context.insert(legPress)
        let machine = Machine(manufacturer: "Gym80", exercise: legPress, gym: fitx)
        context.insert(machine)
        context.insert(Entry(
            reps: 10, weight: 160, date: daysAgo(offsetDays + 3), exercise: legPress, machine: machine
        ))
        try? context.save()
    }

    private static func nineErgs(offsetDays: Double) -> [ProtoErg] {
        func at(_ days: Double) -> Date { daysAgo(offsetDays + days) }
        return [
            ProtoErg(
                name: "Treadmill", unit: "km/h",
                machines: [
                    "FitX Mitte · Technogym Run", "McFit Ost · Life Fitness 95T",
                    "Urban Sports · Woodway", "Hotel Lisbon · Matrix T7",
                ],
                last: ProtoInterval(duration: "6:00", intensity: "15.0 km/h", average: 168, peak: 174, date: at(0))
            ),
            ProtoErg(
                name: "Rower", unit: "/500 m", machines: [],
                last: ProtoInterval(duration: "4:00", intensity: "1:52 /500 m", average: 171, peak: 178, date: at(2))
            ),
            ProtoErg(
                name: "SkiErg", unit: "/500 m", machines: [],
                last: ProtoInterval(duration: "2:00", intensity: "1:58 /500 m", average: 165, peak: 172, date: at(5))
            ),
            ProtoErg(
                name: "Bike Erg", unit: "W", machines: [],
                last: ProtoInterval(duration: "8:00", intensity: "210 W", average: 158, peak: 164, date: at(4))
            ),
            ProtoErg(
                name: "Stairmaster", unit: "level",
                machines: ["FitX Mitte · StairMaster 8G", "McFit Ost · Matrix C5x"],
                last: ProtoInterval(duration: "10:00", intensity: "level 9", average: 152, peak: 160, date: at(7))
            ),
            ProtoErg(
                name: "AssaultBike", unit: "W", machines: ["Urban Sports · Assault AirBike"],
                last: ProtoInterval(duration: "0:45", intensity: "520 W", average: 172, peak: 181, date: at(9))
            ),
            ProtoErg(
                name: "EchoBike", unit: "W", machines: ["FitX Mitte · Rogue Echo"],
                last: ProtoInterval(duration: "1:00", intensity: "450 W", average: 170, peak: 179, date: at(12))
            ),
            ProtoErg(
                name: "Curved Treadmill", unit: "km/h", machines: ["Urban Sports · Woodway Curve"],
                last: ProtoInterval(duration: "1:00", intensity: "18.0 km/h", average: 174, peak: 182, date: at(15))
            ),
            ProtoErg(name: "VersaClimber", unit: "level", machines: ["McFit Ost · VersaClimber"], last: nil),
        ]
    }

    private static let threeErgs: [ProtoErg] = [
        ProtoErg(
            name: "Treadmill", unit: "km/h",
            machines: ["FitX Mitte · Technogym Run", "McFit Ost · Life Fitness 95T"],
            last: ProtoInterval(duration: "6:00", intensity: "15.0 km/h", average: 168, peak: 174, date: daysAgo(0))
        ),
        ProtoErg(
            name: "Rower", unit: "/500 m", machines: [],
            last: ProtoInterval(duration: "4:00", intensity: "1:52 /500 m", average: 171, peak: 178, date: daysAgo(2))
        ),
        ProtoErg(
            name: "Stairmaster", unit: "level", machines: ["FitX Mitte · StairMaster 8G"],
            last: ProtoInterval(duration: "10:00", intensity: "level 9", average: 152, peak: 160, date: daysAgo(6))
        ),
    ]
}
