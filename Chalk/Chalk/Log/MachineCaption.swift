import Foundation
import SwiftData

/// **The machine a log sheet writes onto, and the caption that says so and corrects it**
/// — one rule for both halves' sheets (SPEC §6.4, §13.7): strength's above the giant
/// number, endurance's once above the grid.
///
/// **The sheet never resolves a machine — its caller does.** It is handed one; the
/// caption is how you correct it, through the app's one machine picker (§5.3) plus the
/// two rows only a log sheet needs, `New machine here` and `New gym…`. A gym-bound
/// exercise with nothing resolved cannot save (SPEC §3, invariant 4).
///
/// **The current gym is never consulted to resolve a machine here** — only *moved*, and
/// only while logging: picking a machine at another gym moves it at the pick, and a Save
/// on an archived gym's machine un-archives it and makes it current (§7.4). An edit does
/// neither.
struct MachineCaption {

    let exercise: Exercise

    /// The machine the entry is written onto — **the caller's answer, never the
    /// sheet's**. `nil` for a free-weight exercise or a transferable erg, which carry no
    /// machine, and for the one gym-bound case no caller *can* answer: the first log at a
    /// gym with no machine for this exercise, which `New machine here` closes.
    private(set) var machine: Machine?

    /// The rows the caption opens: the same flat menu the detail screen's qualifier
    /// draws (SPEC §5.3), plus a section for every gym that needs one to hold
    /// `New machine here`. Empty where the exercise carries no machine at all.
    private(set) var menu = MachineMenu(machines: [])

    /// Whether the sheet is correcting an entry rather than writing new ones — **the one
    /// thing stickiness splits on** (SPEC §6.4, §6.6).
    let isEditing: Bool

    /// The gyms made from this sheet's own `New gym…`, which hold no machine for this
    /// exercise yet and still need a section to make one in.
    private var addedHere: [Gym] = []

    private let context: ModelContext
    private let gyms: GymsModel

    init(
        exercise: Exercise,
        machine: Machine?,
        isEditing: Bool = false,
        context: ModelContext,
        gyms: GymsModel
    ) {
        self.exercise = exercise
        self.machine = machine
        self.isEditing = isEditing
        self.context = context
        self.gyms = gyms
        refreshMenu()
    }

    /// What the caption reads — `label · gym`, or `No machine` before any exists. `nil`
    /// where the exercise carries no machine: not a disabled row, not a placeholder.
    ///
    /// It is never hidden "unless something is odd" — a strip that comes and goes shifts
    /// the layout and stops being trusted.
    var text: String? {
        guard exercise.isGymBound else { return nil }
        return machine?.caption ?? Self.noMachine
    }

    /// `text` as VoiceOver says it: `Hammer Strength at Fitness X`.
    var spokenText: String? {
        guard exercise.isGymBound else { return nil }
        return machine?.spokenCaption ?? Self.noMachine
    }

    /// What the caption reads before any machine exists — the one case no caller can
    /// resolve, closed by `New machine here` inside the picker (SPEC §6.4).
    static let noMachine = "No machine"

    /// Whether there is something to write onto: a machine, or an exercise that carries
    /// none. **A gym-bound exercise can never log with no machine** (SPEC §3,
    /// invariant 4) — an unscoped entry pollutes the derivation forever.
    var resolves: Bool { machine != nil || !exercise.isGymBound }

    // MARK: - Correcting it

    /// Corrects the machine from the caption's picker. Returns whether the machine in
    /// scope changed, so the sheet knows to re-seed.
    ///
    /// **Picking a machine at another gym while logging silently moves the current gym**
    /// — that is what makes "changeable in one tap" mean anything. **While editing it
    /// never does**: fixing a three-week-old entry from your couch must not relabel what
    /// you log next (SPEC §6.4).
    @discardableResult
    mutating func select(_ machine: Machine) -> Bool {
        // `entry.machine?.exercise == entry.exercise`, held at every write (SPEC §3,
        // invariant 1), so a machine from another exercise is not a correction.
        guard exercise.isGymBound, machine.exercise?.id == exercise.id else { return false }
        // Before the identity check, not after: confirming the machine the caller
        // resolved is exactly the mislabelled-by-stale-sticky-gym case the caption
        // exists to catch, and it moves the current gym like any other pick.
        moveCurrentGym(to: machine.gym)
        guard machine !== self.machine else { return false }
        self.machine = machine
        refreshMenu()
        return true
    }

    /// `New machine here`: the gym is implied by the section the row sits in, so there is
    /// no gym picker and no second decision — the machine is created and **the caption
    /// resolves to it** (SPEC §6.4). Returns whether it did.
    ///
    /// `name` is the optional one-field alert's answer, `nil` where you skipped it. It is
    /// **always asked**, because you cannot know at creation time whether a second
    /// machine is coming.
    ///
    /// **On an erg, a name that looks like one of its machines at this gym picks that
    /// machine** rather than making a twin (SPEC §13.11) — `Machine.made`, the one door
    /// every new machine goes through. A near spelling at *another* gym is
    /// `nearModel(named:at:)`'s warning, put to you before this is called.
    @discardableResult
    mutating func createMachine(at gym: Gym, named name: String?) -> Bool {
        guard exercise.isGymBound else { return false }
        let machine = Machine.made(for: exercise, at: gym, named: name, in: context)
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        return select(machine)
    }

    /// The warning `New machine here` puts to you before making the machine: **this
    /// erg's machine at another gym** that the typed name looks like — *You have a
    /// Technogym Excite at FitX — same model?* — offering its spelling (SPEC §13.11).
    ///
    /// `nil` on a lift, and `nil` for a same-gym match, which is not a warning:
    /// `createMachine` picks that machine.
    func nearModel(named name: String?, at gym: Gym) -> ErgModelMatch? {
        ErgModelMatch.onCreate(name, for: exercise, at: gym)
    }

    /// `New gym…` came back with one. The picker gains its section — **and only its
    /// section**: the machine you are standing at is still the always-asked decision
    /// `New machine here` puts to you (SPEC §6.4).
    mutating func gymCreated(_ gym: Gym) {
        addedHere.append(gym)
        refreshMenu()
    }

    /// What a Save of new entries does to the gym — **once per Save**, however many
    /// entries it writes (SPEC §13.7). **Logging at an archived gym un-archives it** and
    /// makes it where you are standing, which `select` would not do while it was still
    /// archived (SPEC §7.4). There is deliberately no `restore` verb: the one moment you
    /// need a gym back is the moment you are standing in it.
    ///
    /// An *edit* does not do this — correcting an old entry from your couch is not a
    /// visit. The caller saves the context.
    func logged() {
        guard !isEditing, let gym = machine?.gym, gym.isArchived else { return }
        gym.isArchived = false
        gyms.select(gym)
    }

    /// The stickiness half of a pick. **An archived gym is not somewhere you are
    /// standing** — it left the picker (SPEC §7.4), so it becomes the current gym when
    /// the log lands and un-archives it, not when you tap its row.
    private func moveCurrentGym(to gym: Gym?) {
        guard !isEditing, let gym, !gym.isArchived, gym !== gyms.currentGym else { return }
        gyms.select(gym)
    }

    /// The picker's rows, rebuilt whenever a machine is made or picked. Sectioned by gym,
    /// with the gyms holding no machine for this exercise yet included: `New machine
    /// here` lives in a gym section, and the gym you are standing in has to have one.
    private mutating func refreshMenu() {
        guard exercise.isGymBound else {
            menu = MachineMenu(machines: [])
            return
        }
        menu = MachineMenu(
            machines: exercise.machines ?? [],
            currentGym: gyms.currentGym,
            including: gymsNeedingASection
        )
    }

    /// The gyms that get a section of their own without holding a machine for this
    /// exercise — **the two `New machine here` has to be reachable in, and no more**.
    /// A section per gym you own would turn a flat one-decision picker into a list to
    /// walk down on the log path (SPEC §5.3).
    ///
    /// The gym you are standing in is the hole §6.4 names: the first gym-bound log at a
    /// gym with no machine for this exercise. A gym made from this sheet's own
    /// `New gym…` is the same hole one step later, and would otherwise be a door onto
    /// nothing.
    private var gymsNeedingASection: [Gym] {
        [gyms.currentGym].compactMap { $0 } + addedHere
    }
}
