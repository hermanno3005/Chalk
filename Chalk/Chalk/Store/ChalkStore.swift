import Foundation
import SwiftData

/// The result of trying to open the store. Failure is a value, not a trap: the app
/// shows the path and stops (SPEC §3).
enum StoreOpenOutcome {
    case opened(ModelContainer)
    case failed(storePath: String, error: any Error)
}

/// Opens Chalk's local-only SwiftData store.
///
/// Local-only is deliberate — CloudKit needs a paid Apple Developer Program membership,
/// which collides with free sideloading — but the schema obeys every CloudKit mirroring
/// rule so that enabling sync later is a capability change plus one line (ADR-0001).
enum ChalkStore {
    /// Where SwiftData puts its store by default when given no explicit URL.
    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "default.store")
    }

    /// Opens the store, or reports why it could not be opened and where it lives.
    ///
    /// On failure this **does not** delete, move, recreate or retry against the store
    /// file. Deleting is the one action that loses history irrecoverably (SPEC §2).
    static func open(at url: URL = defaultURL) -> StoreOpenOutcome {
        let schema = Schema(versionedSchema: ChalkSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        do {
            // SwiftData creates this itself when it picks the URL, but not when it is
            // handed one. `Library/Application Support` does not exist in a fresh app
            // container, so without this the very first launch fails to open.
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ChalkMigrationPlan.self,
                configurations: [configuration]
            )
            return .opened(container)
        } catch {
            return .failed(storePath: url.path(percentEncoded: false), error: error)
        }
    }
}
