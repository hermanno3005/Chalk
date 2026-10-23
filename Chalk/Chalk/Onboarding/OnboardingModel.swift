import Foundation
import Observation
import SwiftData

/// Onboarding's state (SPEC §15.3, ADR-0009, ADR-0010): **one screen**, the weight unit, the
/// distance unit and a quieter *Restore from a backup*. No tour and no setup flow: gyms,
/// zones and exercises are still asked for at the moment they matter.
///
/// **It shows only while no units are stored.** Picking them, or restoring, stores both, so
/// it never comes back, not even after the last exercise is deleted. An install from before
/// units already has kg and km, which the launch stores over a library that isn't empty, so
/// it never sees this.
@Observable
final class OnboardingModel {

    /// The weight unit picked. Opens on kg, which an unset unit already reads as.
    var weightUnit: WeightUnit = .kg
    /// The distance unit picked. Opens on km, which an unset unit already reads as.
    var distanceUnit: DistanceUnit = .km

    /// Set once both units are stored, by a pick or a restore, so the app can open the
    /// library in its place.
    var unitsStored: Bool { picked || restoreFlow.restored }

    /// What a restore over a library that is not empty asks before replacing it, or `nil`
    /// while nothing is waiting on an answer. Onboarding only shows over an empty library,
    /// so this is the restore's own guard, never its first answer.
    var restoreConfirmation: String? { restoreFlow.confirmation }

    /// Why the last backup picked was not restored, in plain words. Nothing was changed.
    var restoreFailure: String? {
        get { restoreFlow.failure }
        set { restoreFlow.failure = newValue }
    }

    private var picked = false
    /// *Restore from a backup*, which takes both units from the file.
    private var restoreFlow: RestoreFlow
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults, container: ModelContainer) {
        self.defaults = defaults
        restoreFlow = RestoreFlow(over: container, defaults: defaults)
    }

    /// Whether a launch opens on onboarding: **while no units are stored**, which the
    /// launch leaves so only over an empty library. Checked here too, so a library that
    /// can't be counted never opens on a pick that would relabel its numbers; it reads as
    /// kg and km, as it did before units.
    static func isShown(defaults: UserDefaults, context: ModelContext) -> Bool {
        guard WeightUnit.stored(in: defaults) == nil, DistanceUnit.stored(in: defaults) == nil else { return false }
        return (try? LibraryCounts(context))?.isEmpty == true
    }

    /// Stores the two units picked.
    func pick() {
        weightUnit.save(to: defaults)
        distanceUnit.save(to: defaults)
        picked = true
    }

    /// Restores the backup in `data` over the empty library, as Settings' *Restore from a
    /// backup* does (SPEC §15.1), taking both units from the file.
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
}
