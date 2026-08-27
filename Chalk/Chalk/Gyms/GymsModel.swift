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
/// create-exercise sheet, and the log sheet's picker — so `New gym…` warns on a
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
        save()
        return gym
    }

    /// Renames a gym. **Cosmetic, and that is the whole point**: identity is `Gym.id`
    /// and the current-gym setting holds that UUID rather than the name, so a rename
    /// leaves every machine, every entry and where you are standing untouched.
    ///
    /// A blank name leaves it alone — an unnamed gym is not a rename anyone meant.
    func rename(_ gym: Gym, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        gym.name = name
        save()
    }

    /// Archives a gym — **the removal primitive** (SPEC §7.4). It **hides, never
    /// destroys**: the gym keeps its machines and every entry they hold, and its
    /// rep-maxes stay derivable forever, because the derivation never sees `isArchived`.
    ///
    /// **Archiving the gym you are standing in clears the current-gym setting** rather
    /// than leaving it pointed at something hidden. There is no `restore` verb to pair
    /// with this one: logging at the gym un-archives it, and the moment you need one back
    /// is the moment you are standing in it.
    func archive(_ gym: Gym) {
        gym.isArchived = true
        // The stored UUID is cleared, not merely resolved past: `refresh()` would read
        // an archived gym as *no gym selected* anyway, but leaving the key behind would
        // let un-archiving it elsewhere silently put you back in it.
        if defaults.string(forKey: Self.currentGymKey) == gym.id.uuidString {
            defaults.removeObject(forKey: Self.currentGymKey)
        }
        save()
    }

    /// Whether the hard delete is offered at all: **only for a gym with no machines** —
    /// the typo you just made, where there is nothing to lose. "Delete" and "lose
    /// history" never share a tap, so everything else archives instead.
    func canDelete(_ gym: Gym) -> Bool {
        (gym.machines ?? []).isEmpty
    }

    /// Hard-deletes an empty gym, and **refuses any other** — the guard is here rather
    /// than only in the row that draws the swipe, because this is the one call in the
    /// gym admin surface that takes something out of the store for good.
    func delete(_ gym: Gym) {
        guard canDelete(gym) else { return }

        if defaults.string(forKey: Self.currentGymKey) == gym.id.uuidString {
            defaults.removeObject(forKey: Self.currentGymKey)
        }
        context.delete(gym)
        save()
    }

    /// `Move to another gym…` — repoints a machine at another gym (SPEC §7.5).
    ///
    /// **Its entries follow it**, because they hang off the machine and never off the
    /// gym: nothing is re-pointed here but the one relationship, and the curves are
    /// simply correct on the next read (ADR-0002). This fixes the commoner mistake — a
    /// machine filed under the wrong gym — and is half the duplicate-gym repair: move the
    /// machines across, then archive the husk. **There is no gym merge.**
    /// The gyms `Move to another gym…` offers for a machine held at `gym`: **every other
    /// gym you own**, the ones you still use first and archived ones after them.
    ///
    /// Archived gyms are targets too, deliberately. Moving a machine *out* of a husk is
    /// half the duplicate-gym repair, and the mistake it repairs runs both ways — archive
    /// the wrong one of a pair and the machines you want back together are on the hidden
    /// side of it. There is no `restore` verb to reach for instead (SPEC §7.4).
    func moveTargets(excluding gym: Gym) -> [Gym] {
        let list = ManageGymsList(gyms: allGyms)
        return (list.inUse + list.archived).filter { $0.id != gym.id }
    }

    func move(_ machine: Machine, to gym: Gym) {
        machine.gym = gym
        save()
    }

    /// `Merge into…` — re-points **every** entry from `loser` onto a sibling and then
    /// **hard-deletes** the loser (SPEC §7.5). All-or-nothing, and **no undo**: once the
    /// entries have moved, nothing records that they were ever separate.
    ///
    /// > **The one genuinely dangerous line in the app.** Deletion cascades from
    /// > `Machine` to its entries (SPEC §3), so the order below is load-bearing: the
    /// > reassignment is **flushed to the store before the delete**, and a flush that
    /// > fails abandons the merge rather than arming the cascade over entries still
    /// > pointed at the loser. This is the one write in the app whose save error is not
    /// > swallowed — everywhere else the change simply stays in the context and the next
    /// > save takes it with it; here the next statement destroys history.
    ///
    /// Nothing is recomputed afterwards: no rep-max is stored, so the sibling's curve is
    /// simply correct on the next read (ADR-0002).
    ///
    /// **A machine that is not a same-gym, same-exercise sibling is refused** — the guard
    /// is here rather than only in the row that draws the menu, because this is the one
    /// call in the app that takes history out of the store for good.
    func merge(_ loser: Machine, into sibling: Machine) {
        guard MachineMerge.targets(for: loser).contains(where: { $0 === sibling }) else {
            return
        }

        for entry in loser.entries ?? [] {
            entry.machine = sibling
        }
        do {
            try context.save()
        } catch {
            // The re-pointing never reached the store, so the entries are still the
            // loser's and deleting it would cascade over them. A duplicate row is a
            // nuisance; a lost curve is not.
            return
        }

        context.delete(loser)
        save()
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

    /// As everywhere else: v1 has no error state past §3's container failure and no
    /// network, so there is nothing here to report and nothing to retry — the change
    /// stays in the context either way and the next save takes it with it.
    private func save() {
        try? context.save()
        refresh()
    }
}
