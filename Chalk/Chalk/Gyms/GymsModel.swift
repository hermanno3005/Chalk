import Foundation
import Observation
import SwiftData

/// The gyms the app knows about, and **the current gym** — the one you are standing in
/// (SPEC §7.4, §3).
///
/// The current gym is `@AppStorage("currentGymID")`, a `Gym.id` UUID string, and it is
/// **device local by construction**: a property of a device in a moment, not of your
/// account. A stale or missing UUID resolves to *no gym selected*, which is a state the
/// app has rather than an error it repairs.
///
/// One model shared by every door that touches a gym — the library's Gym menu, the
/// create-exercise sheet, and the log sheet's picker (#28) — so `New gym…` warns on a
/// near name in all of them without three copies of the rule.
@Observable
final class GymsModel {

    /// The `@AppStorage` key SPEC §3 names. Held here so the views that read it through
    /// `@AppStorage` and the models that read it through `UserDefaults` cannot drift.
    static let currentGymKey = "currentGymID"

    /// The gyms the current-gym picker offers: **not archived**, in recency order, with
    /// the current gym pinned to the top. An archived gym leaves the picker and keeps
    /// every entry it holds (SPEC §7.4).
    private(set) var gyms: [Gym] = []

    /// Every gym, archived included — what the near-name warning is checked against, and
    /// what the machine menu sections itself by.
    private(set) var allGyms: [Gym] = []

    /// Where you are standing, or `nil` for *no gym selected*.
    private(set) var currentGym: Gym?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let defaults: UserDefaults

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
        refresh()
    }

    /// Sets the gym you are standing in — or clears it, which is what archiving the gym
    /// you are in does rather than leaving the setting pointed at something hidden.
    func select(_ gym: Gym?) {
        if let gym {
            defaults.set(gym.id.uuidString, forKey: Self.currentGymKey)
        } else {
            defaults.removeObject(forKey: Self.currentGymKey)
        }
        refresh()
    }

    /// Creates a gym and returns it. **Held explicitly on the store, never derived from
    /// the machines that happen to exist** — a newly created empty gym survives the sheet
    /// closing (SPEC §3, invariant 7).
    ///
    /// A near name **warns at the door**, it does not block here: two gyms really can be
    /// called *Fitness X*, and the warning is the user's to overrule.
    @discardableResult
    func create(named name: String) -> Gym? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let gym = Gym(name: name)
        context.insert(gym)
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        refresh()
        return gym
    }

    /// The existing gym a typed name looks like, archived ones included (SPEC §7.4).
    func nearMatch(for name: String) -> Gym? {
        GymNameMatch.nearMatch(for: name, among: allGyms)
    }

    /// Re-reads the gyms and re-resolves the current one. Called at init, and again by
    /// anything that creates a gym or logs an entry — recency order is derived from
    /// entries, so a log anywhere can move it.
    func refresh() {
        allGyms = (try? context.fetch(FetchDescriptor<Gym>())) ?? []

        // A stale UUID — a gym deleted on another device, or before a reinstall —
        // resolves to no gym selected rather than to a repair.
        let storedID = defaults.string(forKey: Self.currentGymKey).flatMap(UUID.init(uuidString:))
        let stored = allGyms.first { $0.id == storedID }
        // An archived gym is not somewhere you are standing: it left the picker, so it
        // stops being the current gym too.
        currentGym = (stored?.isArchived == true) ? nil : stored

        gyms = GymOrder.byRecency(allGyms.filter { !$0.isArchived }, current: currentGym)
    }
}
