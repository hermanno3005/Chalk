import Foundation
import SwiftData

/// *Restore from a backup*, from the file picked to the library replaced, as Settings and
/// onboarding both offer it (SPEC §15.1, §15.3): at once over a library that is empty,
/// otherwise once the question it asks is answered yes. A file Chalk can't restore changes
/// nothing and says why. **No automatic backup is made first** (ADR-0010).
struct RestoreFlow {

    /// What a restore over a library that is not empty asks before replacing it, or `nil`
    /// while nothing is waiting on an answer.
    var confirmation: String? { pending?.confirmation() }

    /// Why the last backup picked was not restored, in plain words. Nothing was changed.
    var failure: String?

    /// Set once a restore has replaced everything.
    private(set) var restored = false

    /// A restore waiting on the answer to its confirmation.
    private var pending: Restore?
    private let container: ModelContainer
    private let defaults: UserDefaults

    /// A restore over everything `container` and `defaults` hold.
    init(over container: ModelContainer, defaults: UserDefaults) {
        self.container = container
        self.defaults = defaults
    }

    /// Restores the backup in `data` in place of everything Chalk holds, or asks first
    /// over a library that is not empty.
    mutating func restore(_ data: Data) {
        pending = nil
        do {
            let restore = try Restore(reading: data, over: container, defaults: defaults)
            if restore.confirmation() != nil {
                pending = restore
            } else {
                try replace(with: restore)
            }
        } catch {
            fail(error)
        }
    }

    /// Restores the backup the importer picked, as `restore(_:)` does.
    mutating func restore(contentsOf url: URL) {
        do {
            restore(try BackupFile.read(url))
        } catch {
            failure = String(localized: "Chalk couldn't open this file. Nothing was changed.")
        }
    }

    /// Answers the question yes: replaces everything with the backup it asked about.
    mutating func confirm() {
        guard let restore = pending else { return }
        pending = nil
        do {
            try replace(with: restore)
        } catch {
            fail(error)
        }
    }

    /// Answers the question no. Nothing changes.
    mutating func cancel() {
        pending = nil
    }

    private mutating func replace(with restore: Restore) throws {
        try restore.replace()
        restored = true
    }

    private mutating func fail(_ error: any Error) {
        failure = (error as? Backup.Refusal)?.message
            ?? String(localized: "Chalk couldn't restore this backup. Nothing was changed.")
    }
}
