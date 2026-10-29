import AppIntents
import SwiftData

/// The library as the system reaches it: the entity queries read it, the Open intents
/// route into it, and Spotlight's index follows it (SPEC §15.5).
///
/// **One per process**, registered with `AppDependencyManager` in `ChalkApp.init`, before
/// any intent runs, so a cold launch from a result works as one from the background. It
/// is told about every open of the store, since a restore, a convert and onboarding all
/// reopen it onto a new container and a new `LibraryModel`. An intent can't reach a
/// view's state, so it reaches the library through this.
@MainActor
final class LibraryRouter {
    private var container: ModelContainer?
    /// The library on screen. `nil` during onboarding, whose library is empty.
    private var library: LibraryModel?
    /// Spotlight's copy, watching this store's main context.
    private var index: LibraryIndex?
    private let sink: any LibraryIndexSink

    init(sink: any LibraryIndexSink) {
        self.sink = sink
    }

    /// The store just opened, and the library on it once onboarding is past. The index
    /// is rebuilt whole, as at any launch: a restore replaced every row behind it.
    func opened(_ container: ModelContainer, library: LibraryModel?) {
        self.container = container
        self.library = library
        index = LibraryIndex(context: container.mainContext, sink: sink)
        index?.sync()
    }

    /// The store failed to open (SPEC §3): nothing can be listed or opened, and
    /// `StoreUnavailableView` stays up.
    func failed() {
        container = nil
        library = nil
        index = nil
    }

    /// Every row in `half`, read through a context of its own.
    func rows(in half: Half) throws -> [IndexedRow] {
        guard let container else { throw LibraryUnavailable() }
        return try IndexedRow.all(in: ModelContext(container)).filter { $0.half == half }
    }

    /// Opens the exercise or erg with this id. A row deleted since Spotlight last heard
    /// opens nothing.
    func open(_ id: UUID) throws {
        guard let library else { throw LibraryUnavailable() }
        library.open(exerciseWithID: id)
    }
}

/// Why an intent can't reach the library: the store didn't open, or onboarding is up.
struct LibraryUnavailable: Error, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource {
        "Chalk can't open your library right now."
    }
}
