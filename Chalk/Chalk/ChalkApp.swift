import SwiftData
import SwiftUI

@main
struct ChalkApp: App {
    private let root: Root

    init() {
        // A backup shared before the app last quit is no longer being copied anywhere,
        // and Chalk keeps none of its own (ADR-0010).
        BackupFile.clear()
        switch ChalkStore.open() {
        case .opened(let container):
            // The library model is made once, here, rather than per body evaluation: it
            // caches the library's ordering and seeds the suggested groups (SPEC §7.2).
            root = .library(container, LibraryModel(context: container.mainContext))
        case .failed(let storePath, _):
            root = .unavailable(storePath)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch root {
            case .library(let container, let model):
                LibraryView(model: model)
                    .modelContainer(container)
            case .unavailable(let storePath):
                StoreUnavailableView(storePath: storePath)
            }
        }
    }

    /// What the app opens into. A failed store is a value, not a trap (SPEC §3).
    private enum Root {
        case library(ModelContainer, LibraryModel)
        case unavailable(String)
    }
}
