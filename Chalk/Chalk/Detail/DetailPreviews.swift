import SwiftData
import SwiftUI

// Both detail screens at the default text size and at the largest accessibility size,
// where the screen gives way as SPEC §15.4 orders it: the chart shrinks to 110 pt, then
// the screen scrolls with the chart at 210 pt and the Log bar pinned.

#Preview("Lift") {
    DetailPreview.lift()
}

#Preview("Lift, AX5") {
    DetailPreview.lift()
        .dynamicTypeSize(.accessibility5)
}

#Preview("Erg") {
    DetailPreview.erg()
}

#Preview("Erg, AX5") {
    DetailPreview.erg()
        .dynamicTypeSize(.accessibility5)
}

/// An in-memory library holding one lift and one speed erg with a goal each, so the
/// previews above are the real screens over the real models.
private enum DetailPreview {
    @MainActor
    static func lift() -> some View {
        guard let (context, defaults) = store() else { return AnyView(Text("No preview store.")) }
        let bench = Exercise(name: "Bench Press")
        bench.goalReps = 5
        bench.goalWeight = 110
        bench.goalSetAt = .now.addingTimeInterval(-86_400 * 30)
        context.insert(bench)
        for (index, (reps, weight)) in [(1, 115.0), (3, 107.5), (5, 102.5), (8, 92.5), (12, 80)].enumerated() {
            context.insert(Entry(
                reps: reps,
                weight: weight,
                date: .now.addingTimeInterval(-86_400 * Double(index)),
                exercise: bench
            ))
        }
        let model = ExerciseDetailModel(
            exercise: bench,
            context: context,
            gyms: GymsModel(context: context, defaults: defaults),
            weightUnit: .kg
        )
        return AnyView(NavigationStack { ExerciseDetailView(model: model) })
    }

    @MainActor
    static func erg() -> some View {
        guard let (context, defaults) = store() else { return AnyView(Text("No preview store.")) }
        HeartRateZones(lowerBounds: [120, 140, 155, 170])?.save(to: defaults)
        let treadmill = Exercise(name: "Treadmill", unit: .speed)
        treadmill.goalZone = 4
        treadmill.goalDuration = 360
        treadmill.goalIntensity = 15.5
        treadmill.goalIncline = 0
        treadmill.goalSetAt = .now.addingTimeInterval(-86_400 * 30)
        context.insert(treadmill)
        for (index, (duration, speed)) in [(120, 16.5), (360, 15.1), (600, 14.2), (900, 13.4)].enumerated() {
            context.insert(Entry(
                duration: duration,
                intensity: speed,
                averageHeartRate: 164,
                peakHeartRate: 172,
                date: .now.addingTimeInterval(-86_400 * Double(index)),
                exercise: treadmill
            ))
        }
        let model = ErgDetailModel(
            erg: treadmill,
            context: context,
            gyms: GymsModel(context: context, defaults: defaults),
            defaults: defaults
        )
        return AnyView(NavigationStack { ErgDetailView(model: model) })
    }

    @MainActor
    private static func store() -> (ModelContext, UserDefaults)? {
        guard
            let container = try? ModelContainer(
                for: Schema(versionedSchema: ChalkSchemaV1.self),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ),
            // A suite of its own, so a preview never writes into the defaults a running
            // app reads.
            let defaults = UserDefaults(suiteName: "chalk-preview-\(UUID().uuidString)")
        else { return nil }
        return (ModelContext(container), defaults)
    }
}
