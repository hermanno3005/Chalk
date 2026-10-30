import AppIntents
import SwiftData
import SwiftUI

@main
struct ChalkApp: App {
    @State private var root: Root

    /// How Spotlight and Shortcuts reach the library (SPEC §15.5). Registered before the
    /// store opens, so an intent never finds it missing, even when the store failed.
    private static let router = LibraryRouter(sink: SpotlightIndex())

    init() {
        // A backup shared before the app last quit is no longer being copied anywhere,
        // and Chalk keeps none of its own (ADR-0010).
        BackupFile.clear()
        let router = Self.router
        AppDependencyManager.shared.add(dependency: router)
        #if DEBUG
        ScreenshotLibrary.restoreIfAsked()
        #endif
        let root = Self.open()
        #if DEBUG
        if case .library(let container, let library) = root {
            ScreenshotLibrary.openIfAsked(in: container.mainContext, library: library)
        }
        #endif
        _root = State(initialValue: root)
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
            case .onboarding(let model):
                OnboardingView(model: model)
                    .environment(\.reopenLibrary, ReopenLibraryAction { root = Self.open() })
            case .unavailable(let storePath):
                StoreUnavailableView(storePath: storePath)
            }
        }
    }

    /// Opens the store and the library on it, or onboarding while no units are stored.
    /// Run at launch, and again after onboarding or a restore, so the restored library is
    /// read fresh rather than through a context whose rows another context deleted.
    private static func open() -> Root {
        switch ChalkStore.open() {
        case .opened(let container):
            // The library model is made once per open, rather than per body evaluation:
            // it caches the library's ordering and seeds the suggested groups (SPEC §7.2).
            // It is made before onboarding is decided, since it stores kg and km over a
            // library that isn't empty, which then never sees onboarding (SPEC §15.3).
            let library = LibraryModel(context: container.mainContext)
            let onboarding = OnboardingModel.isShown(defaults: .standard, context: container.mainContext)
            router.opened(container, library: onboarding ? nil : library)
            return onboarding
                ? .onboarding(OnboardingModel(defaults: .standard, container: container))
                : .library(container, library)
        case .failed(let storePath, _):
            router.failed()
            return .unavailable(storePath)
        }
    }

    /// What the app opens into. A failed store is a value, not a trap (SPEC §3).
    private enum Root {
        case library(ModelContainer, LibraryModel)
        case onboarding(OnboardingModel)
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
