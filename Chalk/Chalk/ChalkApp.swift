import SwiftUI

// PROTOTYPE — the app is rooted at the goals prototype while this branch is checked
// out, not at `LibraryView`. This is why prototype source never lands on `main`
// (docs/agents/branch-lifecycle.md).
@main
struct ChalkApp: App {
    var body: some Scene {
        WindowGroup {
            GoalsPrototypeRoot()
        }
    }
}
