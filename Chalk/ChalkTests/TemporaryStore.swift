import Foundation
import SwiftData
import Testing

@testable import Chalk

/// A real on-disk store in a fresh temporary directory, opened through `ChalkStore`
/// so the tests exercise the same path the app takes.
struct TemporaryStore {
    let url: URL
    let container: ModelContainer

    init() throws {
        url = try Self.unusedStoreURL()
        container = try Self.openContainer(at: url)
    }

    /// A path in a directory of its own that no store has been written to yet.
    static func unusedStoreURL() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: "chalk-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "Chalk.store")
    }

    /// Inserts models of mixed types, which otherwise needs an existential cast at
    /// every call site.
    func insertAll(_ models: [any PersistentModel], into context: ModelContext) throws {
        for model in models {
            context.insert(model)
        }
        try context.save()
    }

    /// A second, independent container over the same file. It has its own cache, so a
    /// fetch through it reads what `save()` actually put on disk — but the first
    /// container stays open, so this is not a close-and-reopen.
    func reopened() throws -> ModelContainer {
        try Self.openContainer(at: url)
    }

    private static func openContainer(at url: URL) throws -> ModelContainer {
        switch ChalkStore.open(at: url) {
        case .opened(let container):
            return container
        case .failed(_, let error):
            throw error
        }
    }
}
