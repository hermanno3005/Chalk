import Foundation
import Observation
import SwiftData

/// Settings' state (ADR-0005): Chalk's one settings screen, holding your heart-rate zones
/// and the **weight** and **distance units** (ADR-0009), and where a **backup** is made and
/// **restored** (ADR-0010). Each further setting is its own decision, never a row added in
/// passing.
///
/// Four whole-bpm fields, the lower bounds of Z2 to Z5. A save needs all four, each 40–230
/// and strictly higher than the one below — `HeartRateZones`' own rule, so the screen and
/// every reader agree on what a set of zones is. **Edit only, never clear:** there is no
/// clear verb, and a blanked field only disables the save, so once zones are set nothing
/// that depends on them is gated again, short of restoring a backup made without them.
///
/// **A unit change is made at once**, not on Save: while nothing is written on its scale it
/// is just a change, and once there is it waits on one question, answered by a relabel or
/// a convert, and a convert asks once more with its count.
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
    var restoreConfirmation: String? { restoreFlow.confirmation }

    /// Why the last backup picked was not restored, in plain words. Nothing was changed.
    var restoreFailure: String? {
        get { restoreFlow.failure }
        set { restoreFlow.failure = newValue }
    }

    /// Set once a restore has replaced everything, so the app can reopen on the restored
    /// library as a relaunch would.
    var restored: Bool { restoreFlow.restored }

    /// Set once a convert has rewritten a scale, so the app can reopen on the converted
    /// library as a restore does: every screen behind Settings holds the old rows.
    private(set) var converted = false

    /// The scale every strength weight and goal is written on.
    private(set) var weightUnit: WeightUnit
    /// The scale every speed and speed goal is written on.
    private(set) var distanceUnit: DistanceUnit

    /// A unit change waiting on the answer to its question, relabel or convert, or `nil`
    /// while nothing is.
    private(set) var unitChange: UnitChange?

    /// What a convert asks before it rewrites a scale, or `nil` while nothing is waiting
    /// on an answer.
    var convertConfirmation: String? { pendingConvert?.confirmation() }

    /// Why the last convert didn't happen, in plain words. Nothing was changed.
    var convertFailure: String?

    /// A convert waiting on the answer to its confirmation, or `nil` while nothing is.
    private(set) var pendingConvert: Convert?

    /// *Restore from a backup*, from the file picked to the library replaced.
    private var restoreFlow: RestoreFlow
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let container: ModelContainer

    init(defaults: UserDefaults, container: ModelContainer) {
        self.defaults = defaults
        self.container = container
        restoreFlow = RestoreFlow(over: container, defaults: defaults)
        backup = BackupFile(container: container, settings: Backup.Settings(defaults: defaults))
        weightUnit = WeightUnit(defaults: defaults)
        distanceUnit = DistanceUnit(defaults: defaults)
        if let zones = HeartRateZones(defaults: defaults) {
            lowerBounds = zones.lowerBounds
        }
    }

    /// Writes the typed zones over the held ones. Does nothing unless `canSave`, so no
    /// caller can save a partial or impossible set, or clear one.
    func save() {
        typedZones?.save(to: defaults)
    }

    /// Asks to write every weight in `unit`. The unit already held asks nothing.
    func change(weightsTo unit: WeightUnit) {
        guard unit != weightUnit else { return }
        ask(.weights(unit))
    }

    /// Asks to write every speed in `unit`. The unit already held asks nothing.
    func change(distancesTo unit: DistanceUnit) {
        guard unit != distanceUnit else { return }
        ask(.distances(unit))
    }

    /// Answers the unit change's question with a relabel: the scale moves, and every
    /// number stays.
    func relabel() {
        guard let change = unitChange else { return }
        unitChange = nil
        change.relabel(in: defaults)
        weightUnit = WeightUnit(defaults: defaults)
        distanceUnit = DistanceUnit(defaults: defaults)
    }

    /// Answers the unit change's question no. The unit and every number stay as they are.
    func cancelUnitChange() {
        unitChange = nil
    }

    /// Answers the unit change's question with a convert, which asks once more, with a
    /// count, before it rewrites anything.
    func askToConvert() {
        guard let change = unitChange else { return }
        unitChange = nil
        do {
            pendingConvert = try Convert(change, over: container, defaults: defaults)
        } catch {
            convertFailure = Self.convertFailed
        }
    }

    /// Answers the convert's confirmation yes: every number on the scale is rewritten onto
    /// the new one, and the scale moves. A convert that fails changes nothing and says so.
    func convert() {
        guard let convert = pendingConvert else { return }
        pendingConvert = nil
        do {
            try convert.convert()
            converted = true
        } catch {
            convertFailure = Self.convertFailed
        }
        weightUnit = WeightUnit(defaults: defaults)
        distanceUnit = DistanceUnit(defaults: defaults)
    }

    /// Answers the convert's confirmation no. The unit and every number stay as they are.
    func cancelConvert() {
        pendingConvert = nil
    }

    private static let convertFailed = String(localized: "Chalk couldn't convert. Nothing was changed.")

    /// Holds `change` for the question, and makes it at once while nothing is written on
    /// its scale: with no number to keep, a relabel is just a change.
    private func ask(_ change: UnitChange) {
        unitChange = change
        // A store that can't be read asks, which is never the wrong thing to do.
        if (try? change.isWritten(in: ModelContext(container))) == false { relabel() }
    }

    /// Restores the backup in `data` in place of everything Chalk holds: at once over a
    /// library that is empty, otherwise once `confirmRestore()` answers the question it
    /// asks. A file Chalk can't restore changes nothing and says why. **No automatic
    /// backup is made first**, not even here (ADR-0010).
    func restore(_ data: Data) {
        restoreFlow.restore(data)
    }

    /// Restores the backup the importer picked, as `restore(_:)` does.
    func restore(contentsOf url: URL) {
        restoreFlow.restore(contentsOf: url)
    }

    /// Answers the question yes: replaces everything with the backup it asked about.
    func confirmRestore() {
        restoreFlow.confirm()
    }

    /// Answers the question no. Nothing changes.
    func cancelRestore() {
        restoreFlow.cancel()
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
