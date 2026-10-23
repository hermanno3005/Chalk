import SwiftData
import SwiftUI

// PROTOTYPE — the app root while this prototype is checked out (#141).
//
// The real exercise detail screen in identity E, over sample exercises held in a scratch
// store that is wiped on every launch. The black bar below the app switches the plate
// breakdown's variant (‹ ›), the exercise and the appearance; the bar itself is set from
// the screen's own overflow. Launch arguments `-prototype.plates B -prototype.scenario lb
// -prototype.dark YES` open on a given state.

struct PlateBreakdownPrototypeRoot: View {
    @AppStorage("prototype.plates") private var variant = PlateVariant.line.rawValue
    @AppStorage("prototype.scenario") private var scenario = PlateScenario.kg.rawValue
    @AppStorage("prototype.dark") private var dark = false
    @AppStorage("prototype.unit") private var unit = ProtoWeightUnit.kg.rawValue
    @AppStorage("prototype.bar") private var bar = 20.0

    private let sample = PlateLibrary.make()

    private var currentVariant: PlateVariant { PlateVariant(rawValue: variant) ?? .line }
    private var currentScenario: PlateScenario { PlateScenario(rawValue: scenario) ?? .kg }

    /// Opens on 5 reps, or on `-prototype.reps N` for a screenshot.
    private var model: ExerciseDetailModel {
        let model = ExerciseDetailModel(
            exercise: sample.exercise(for: currentScenario),
            context: sample.context,
            gyms: sample.gyms
        )
        let reps = UserDefaults.standard.integer(forKey: "prototype.reps")
        if reps > 0 { model.select(reps) }
        return model
    }

    var body: some View {
        let _ = Palette.current = .tradeRepublic(.layout)
        VStack(spacing: 0) {
            NavigationStack {
                ExerciseDetailView(model: model)
                .toolbar {
                    // Dead: placement only, so the nav bar reads as it does when pushed.
                    ToolbarItem(placement: .topBarLeading) {
                        Image(systemName: "chevron.left").fontWeight(.semibold)
                    }
                }
                .containerBackground(Palette.current.ground, for: .navigation)
            }
            .tint(Palette.current.accent)
            .id("\(variant)-\(scenario)-\(bar)")
            switcher
        }
        .preferredColorScheme(dark ? .dark : .light)
        .onAppear { if !ProcessInfo.processInfo.arguments.contains("-prototype.bar") { apply(currentScenario) } }
    }

    private func apply(_ scenario: PlateScenario) {
        unit = scenario.unit.rawValue
        bar = scenario.bar
    }

    private var switcher: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button { cycleVariant(-1) } label: { Image(systemName: "chevron.left") }
                Text("\(currentVariant.rawValue) — \(currentVariant.name)")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 200)
                Button { cycleVariant(1) } label: { Image(systemName: "chevron.right") }
            }
            HStack(spacing: 6) {
                pill(currentScenario.title) {
                    let all = PlateScenario.allCases
                    let next = all[(all.firstIndex(of: currentScenario)! + 1) % all.count]
                    scenario = next.rawValue
                    apply(next)
                }
                pill(dark ? "Dark" : "Light") { dark.toggle() }
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    private func cycleVariant(_ step: Int) {
        let all = PlateVariant.allCases
        let index = all.firstIndex(of: currentVariant)!
        variant = all[(index + step + all.count) % all.count].rawValue
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.18), in: Capsule())
        }
    }
}

enum PlateScenario: String, CaseIterable {
    /// Bench on a 20 kg bar, one typed entry off the grid at 12 reps.
    case kg
    /// Bench on a 45 lb bar, every entry on the 5 lb grid.
    case lb
    /// The kg bench after a convert: every weight to the nearest 1 lb, the bar to 44 lb.
    case converted
    /// A curl on a 10 kg bar: small plates, and the bar alone at 12 reps.
    case curl

    var title: String {
        switch self {
        case .kg: "Bench · kg · 20 bar"
        case .lb: "Bench · lb · 45 bar"
        case .converted: "Bench · converted · 44 bar"
        case .curl: "Curl · kg · 10 bar"
        }
    }

    var unit: ProtoWeightUnit { self == .kg || self == .curl ? .kg : .lb }

    var bar: Double {
        switch self {
        case .kg: 20
        case .lb: 45
        case .converted: 44
        case .curl: 10
        }
    }
}

@MainActor
struct PlateLibrary {
    let context: ModelContext
    let gyms: GymsModel
    let exercises: [PlateScenario: Exercise]

    func exercise(for scenario: PlateScenario) -> Exercise { exercises[scenario]! }

    static let defaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: "PROTOTYPE-plates-wipe-me")!
        defaults.removePersistentDomain(forName: "PROTOTYPE-plates-wipe-me")
        return defaults
    }()

    private static let container: ModelContainer = {
        let url = URL.temporaryDirectory.appending(path: "PROTOTYPE-plates-wipe-me.store")
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
        }
        guard case .opened(let container) = ChalkStore.open(at: url) else {
            fatalError("PROTOTYPE: scratch store did not open")
        }
        return container
    }()

    private static var made: PlateLibrary?

    static func make() -> PlateLibrary {
        if let made { return made }
        let context = container.mainContext
        let day: (Int) -> Date = { Calendar.current.date(byAdding: .day, value: -$0, to: .now)! }

        func exercise(
            _ name: String, _ lifts: [(Int, Int, Double)], goal: (Int, Double)
        ) -> Exercise {
            let exercise = Exercise(name: name)
            context.insert(exercise)
            for (daysAgo, reps, weight) in lifts {
                context.insert(Entry(reps: reps, weight: weight, date: day(daysAgo), exercise: exercise))
            }
            exercise.goalReps = goal.0
            exercise.goalWeight = goal.1
            exercise.goalSetAt = day(32)
            return exercise
        }

        // (days ago, reps, weight)
        let benchKg: [(Int, Int, Double)] = [
            (34, 5, 92.5), (30, 8, 82.5), (21, 1, 120.0), (18, 3, 110.0),
            (14, 10, 77.5), (9, 8, 85.0), (5, 5, 100.0), (2, 5, 102.5), (12, 12, 61.0),
        ]
        // A convert: to the nearest 1 lb, ties up (SPEC §15.2).
        let toLb: (Double) -> Double = { ($0 * 2.20462262).rounded(.toNearestOrAwayFromZero) }

        let exercises: [PlateScenario: Exercise] = [
            .kg: exercise("Bench Press", benchKg, goal: (5, 110)),
            .lb: exercise("Bench Press", [
                (34, 5, 205), (30, 8, 185), (21, 1, 265), (18, 3, 245),
                (14, 10, 170), (9, 8, 185), (5, 5, 220), (2, 5, 225), (12, 12, 135),
            ], goal: (5, 245)),
            .converted: exercise(
                "Bench Press", benchKg.map { ($0.0, $0.1, toLb($0.2)) }, goal: (5, toLb(110))
            ),
            .curl: exercise("Barbell Curl", [
                (20, 12, 10), (15, 10, 15), (11, 8, 22.5), (6, 5, 27.5), (3, 3, 31),
            ], goal: (8, 25)),
        ]

        try? context.save()
        let library = PlateLibrary(
            context: context,
            gyms: GymsModel(context: context, defaults: defaults),
            exercises: exercises
        )
        made = library
        return library
    }
}
