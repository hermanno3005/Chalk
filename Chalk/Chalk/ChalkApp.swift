import SwiftData
import SwiftUI

@main
struct ChalkApp: App {
    /// Local-only store. Sync is deferred: CloudKit needs a paid Apple Developer
    /// Program membership, which collides with free sideloading. The schema is
    /// still written to CloudKit's rules so `.automatic` is a one-line change later.
    let modelContainer: ModelContainer = {
        let schema = Schema([Placeholder.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // PROTOTYPE BRANCH ONLY — rooted at the exercise-detail prototype.
            ExerciseDetailPrototypeRoot()
        }
        .modelContainer(modelContainer)
    }
}
