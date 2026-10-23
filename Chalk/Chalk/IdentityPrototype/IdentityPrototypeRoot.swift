import SwiftData
import SwiftUI

// PROTOTYPE — the app root while this prototype is checked out (#140).
//
// The real exercise and erg detail screens, unchanged in layout, over a sample library
// held in a scratch store that is wiped on every launch. The black bar below the app
// switches the palette (‹ ›), the screen and the appearance. Launch arguments
// `-prototype.variant B -prototype.screen erg -prototype.dark YES` open on a given state.

struct IdentityPrototypeRoot: View {
    @AppStorage("prototype.variant") private var variant = IdentityVariant.a.rawValue
    @AppStorage("prototype.screen") private var screen = ProtoScreen.exercise.rawValue
    @AppStorage("prototype.dark") private var dark = false

    private let sample = ProtoLibrary.make()

    private var currentVariant: IdentityVariant { IdentityVariant(rawValue: variant) ?? .a }
    private var currentScreen: ProtoScreen { ProtoScreen(rawValue: screen) ?? .exercise }

    var body: some View {
        let _ = Palette.current = currentVariant.palette
        VStack(spacing: 0) {
            NavigationStack {
                Group {
                    switch currentScreen {
                    case .exercise:
                        ExerciseDetailView(model: ExerciseDetailModel(
                            exercise: sample.bench, context: sample.context, gyms: sample.gyms
                        ))
                    case .erg:
                        ErgDetailView(model: ErgDetailModel(
                            erg: sample.treadmill, context: sample.context, gyms: sample.gyms,
                            defaults: ProtoLibrary.defaults
                        ))
                    }
                }
                .toolbar {
                    // Dead: placement only, so the nav bar reads as it does when pushed.
                    ToolbarItem(placement: .topBarLeading) {
                        Image(systemName: "chevron.left").fontWeight(.semibold)
                    }
                }
                .containerBackground(Palette.current.ground, for: .navigation)
            }
            .tint(Palette.current.accent)
            .id("\(variant)-\(screen)")
            switcher
        }
        .preferredColorScheme(dark ? .dark : .light)
    }

    private var switcher: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Button { cycleVariant(-1) } label: { Image(systemName: "chevron.left") }
                Text("\(currentVariant.rawValue) — \(currentVariant.name)")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 170)
                Button { cycleVariant(1) } label: { Image(systemName: "chevron.right") }
            }
            HStack(spacing: 6) {
                pill(currentScreen.title) {
                    screen = (currentScreen == .exercise ? ProtoScreen.erg : .exercise).rawValue
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
        let all = IdentityVariant.allCases
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

enum ProtoScreen: String {
    case exercise, erg

    var title: String {
        switch self {
        case .exercise: "Bench Press"
        case .erg: "Treadmill"
        }
    }
}

/// A free-weight bench press with a goal 7.5 kg away, and a transferable treadmill with
/// zones set, lines in Z2–Z5 at 1 % and a Z4 goal — written straight into a scratch store.
@MainActor
struct ProtoLibrary {
    let context: ModelContext
    let gyms: GymsModel
    let bench: Exercise
    let treadmill: Exercise

    static let defaults: UserDefaults = {
        let defaults = UserDefaults(suiteName: "PROTOTYPE-identity-wipe-me")!
        defaults.removePersistentDomain(forName: "PROTOTYPE-identity-wipe-me")
        HeartRateZones(lowerBounds: [120, 140, 155, 168])!.save(to: defaults)
        return defaults
    }()

    private static let container: ModelContainer = {
        let url = URL.temporaryDirectory.appending(path: "PROTOTYPE-identity-wipe-me.store")
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
        }
        guard case .opened(let container) = ChalkStore.open(at: url) else {
            fatalError("PROTOTYPE: scratch store did not open")
        }
        return container
    }()

    private static var made: ProtoLibrary?

    static func make() -> ProtoLibrary {
        if let made { return made }
        let context = container.mainContext
        let day: (Int) -> Date = { Calendar.current.date(byAdding: .day, value: -$0, to: .now)! }

        let bench = Exercise(name: "Bench Press")
        context.insert(bench)
        for (daysAgo, reps, weight) in [
            (34, 5, 92.5), (30, 8, 82.5), (21, 1, 120.0), (18, 3, 110.0),
            (14, 10, 77.5), (9, 8, 85.0), (5, 5, 100.0), (2, 5, 102.5),
        ] {
            context.insert(Entry(reps: reps, weight: weight, date: day(daysAgo), exercise: bench))
        }
        bench.goalReps = 5
        bench.goalWeight = 110
        bench.goalSetAt = day(32)

        let treadmill = Exercise(name: "Treadmill", unit: .speed)
        context.insert(treadmill)
        // (days ago, seconds, km/h, average bpm). Zones: Z2 from 120, Z3 140, Z4 155, Z5 168.
        for (daysAgo, duration, speed, heartRate) in [
            (40, 1200, 11.0, 130), (33, 900, 11.4, 133),
            (29, 600, 13.0, 147), (24, 900, 12.6, 149), (19, 1200, 12.2, 151),
            (27, 240, 15.5, 160), (22, 360, 14.8, 159), (15, 360, 15.0, 162),
            (12, 600, 14.2, 163), (8, 600, 14.4, 164), (6, 900, 13.6, 165),
            (17, 120, 17.0, 172), (10, 240, 16.2, 174),
            (1, 360, 15.2, 163),
        ] {
            context.insert(Entry(
                duration: duration, intensity: speed, incline: 1,
                averageHeartRate: heartRate, peakHeartRate: heartRate + 8,
                date: day(daysAgo), exercise: treadmill
            ))
        }
        treadmill.goalZone = 4
        treadmill.goalDuration = 600
        treadmill.goalIntensity = 15.0
        treadmill.goalIncline = 1
        treadmill.goalSetAt = day(20)

        try? context.save()
        let library = ProtoLibrary(
            context: context,
            gyms: GymsModel(context: context, defaults: defaults),
            bench: bench,
            treadmill: treadmill
        )
        made = library
        return library
    }
}
