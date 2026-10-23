import Foundation
import Observation
import SwiftData

/// Settings' state (ADR-0005): Chalk's one settings screen, holding your heart-rate zones,
/// and where a **backup** is made and **restored** (ADR-0010). Each further setting is its
/// own decision, never a row added in passing.
///
/// Four whole-bpm fields, the lower bounds of Z2 to Z5. A save needs all four, each 40–230
/// and strictly higher than the one below — `HeartRateZones`' own rule, so the screen and
/// every reader agree on what a set of zones is. **Edit only, never clear:** there is no
/// clear verb, and a blanked field only disables the save, so once zones are set nothing
/// that depends on them is gated again, short of restoring a backup made without them.
@Observable
final class SettingsModel: Identifiable {

    let id = UUID()

    /// The typed lower bounds of Z2, Z3, Z4 and Z5, `nil` where a field is blank. Opens on
    /// the zones this device holds, or four blanks before the first save.
    var lowerBounds: [Int?] = [nil, nil, nil, nil]

    /// Whether the four fields make a set of zones.
    var canSave: Bool { typedZones != nil }

    /// A backup of everything in `container`, handed to the share sheet. Nothing is
    /// written until a destination asks for it.
    let backup: BackupFile

    /// What a restore over a library that is not empty asks before replacing it, or `nil`
    /// while nothing is waiting on an answer.
    private(set) var restoreConfirmation: String?

    /// Why the last backup picked was not restored, in plain words. Nothing was changed.
    var restoreFailure: String?

    /// Set once a restore has replaced everything, so the app can reopen on the restored
    /// library as a relaunch would.
    private(set) var restored = false

    @ObservationIgnored private var pendingRestore: Restore?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let container: ModelContainer

    init(defaults: UserDefaults, container: ModelContainer) {
        self.defaults = defaults
        self.container = container
        backup = BackupFile(container: container, settings: Backup.Settings(defaults: defaults))
        if let zones = HeartRateZones(defaults: defaults) {
            lowerBounds = zones.lowerBounds
        }
    }

    /// Writes the typed zones over the held ones. Does nothing unless `canSave`, so no
    /// caller can save a partial or impossible set, or clear one.
    func save() {
        typedZones?.save(to: defaults)
    }

    /// Restores the backup in `data` in place of everything Chalk holds: at once over a
    /// library that is empty, otherwise once `confirmRestore()` answers the question it
    /// asks. A file Chalk can't restore changes nothing and says why. **No automatic
    /// backup is made first**, not even here (ADR-0010).
    func restore(_ data: Data) {
        pendingRestore = nil
        restoreConfirmation = nil
        do {
            let restore = try Restore(reading: data, over: container, defaults: defaults)
            if let confirmation = restore.confirmation() {
                pendingRestore = restore
                restoreConfirmation = confirmation
            } else {
                try replace(with: restore)
            }
        } catch {
            fail(error)
        }
    }

    /// Restores the backup the importer picked, as `restore(_:)` does.
    func restore(contentsOf url: URL) {
        do {
            restore(try BackupFile.read(url))
        } catch {
            restoreFailure = "Chalk couldn't open this file. Nothing was changed."
        }
    }

    /// Answers the question yes: replaces everything with the backup it asked about.
    func confirmRestore() {
        guard let restore = pendingRestore else { return }
        pendingRestore = nil
        restoreConfirmation = nil
        do {
            try replace(with: restore)
        } catch {
            fail(error)
        }
    }

    /// Answers the question no. Nothing changes.
    func cancelRestore() {
        pendingRestore = nil
        restoreConfirmation = nil
    }

    private func replace(with restore: Restore) throws {
        try restore.replace()
        restored = true
    }

    private func fail(_ error: any Error) {
        restoreFailure = (error as? Backup.Refusal)?.message
            ?? "Chalk couldn't restore this backup. Nothing was changed."
    }

    /// Settings has closed, and the share sheet with it: no destination is still copying
    /// a backup, so Chalk keeps none.
    func close() {
        BackupFile.clear()
    }

    private var typedZones: HeartRateZones? {
        let typed = lowerBounds.compactMap(\.self)
        guard typed.count == lowerBounds.count else { return nil }
        return HeartRateZones(lowerBounds: typed)
    }
}
