import Foundation
import Observation
import SwiftData

/// Settings' state (ADR-0005): Chalk's one settings screen, holding your heart-rate zones,
/// and where a **backup** is made (ADR-0010). Each further setting is its own decision,
/// never a row added in passing.
///
/// Four whole-bpm fields, the lower bounds of Z2 to Z5. A save needs all four, each 40–230
/// and strictly higher than the one below — `HeartRateZones`' own rule, so the screen and
/// every reader agree on what a set of zones is. **Edit only, never clear:** there is no
/// clear verb, and a blanked field only disables the save, so once zones are set nothing
/// that depends on them is gated again.
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

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults, container: ModelContainer) {
        self.defaults = defaults
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
