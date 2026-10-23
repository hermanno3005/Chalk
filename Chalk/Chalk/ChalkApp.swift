import SwiftData
import SwiftUI

@main
struct ChalkApp: App {
    @State private var root: Root

    init() {
        // A backup shared before the app last quit is no longer being copied anywhere,
        // and Chalk keeps none of its own (ADR-0010).
        BackupFile.clear()
        _root = State(initialValue: Self.open())
    }

    var body: some Scene {
        WindowGroup {
            switch root {
            case .library(let container, let model):
                LibraryView(model: model)
                    .modelContainer(container)
                    // A new model is a new library screen, so nothing presented over the
                    // old one, Settings included, survives a reopen.
                    .id(ObjectIdentifier(model))
                    .environment(\.reopenLibrary, ReopenLibraryAction { root = Self.open() })
            case .unavailable(let storePath):
                StoreUnavailableView(storePath: storePath)
            }
        }
    }

    /// Opens the store and the library on it. Run at launch, and again after a restore,
    /// so the restored library is read fresh rather than through a context whose rows
    /// another context deleted.
    private static func open() -> Root {
        switch ChalkStore.open() {
        case .opened(let container):
            // The library model is made once per open, rather than per body evaluation:
            // it caches the library's ordering and seeds the suggested groups (SPEC §7.2).
            .library(container, LibraryModel(context: container.mainContext))
        case .failed(let storePath, _):
            .unavailable(storePath)
        }
    }

    /// What the app opens into. A failed store is a value, not a trap (SPEC §3).
    private enum Root {
        case library(ModelContainer, LibraryModel)
        case unavailable(String)
    }
}

/// Reopens the store and rebuilds the library on it, as a relaunch would. A restore calls
/// it once the store has committed. Read from the environment, as `dismiss` is.
struct ReopenLibraryAction {
    fileprivate let reopen: () -> Void

    func callAsFunction() {
        reopen()
    }
}

extension EnvironmentValues {
    @Entry var reopenLibrary = ReopenLibraryAction {}
}
