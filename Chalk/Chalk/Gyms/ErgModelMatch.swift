import Foundation
import SwiftData

/// **The near-name check on erg machines** (SPEC §7.5, §13.11) — the one rule behind all
/// three doors that name an erg machine: create (`New machine here`), `Rename…`, and
/// `Move to another gym…`.
///
/// It exists for a reason strength machines do not share: **an erg machine's label is its
/// model**, and the hint matches models across gyms *by label* (§13.8), so *Technogym
/// Excite* at one gym and *technogym exite* at another are two models to the hint. The
/// spellings have to converge, and the cheap moment to make them is while one is typed.
///
/// It reuses gym creation's loose matching (`GymNameMatch.looksAlike`) **against that
/// erg's machines at every gym**, **warns and never blocks**, and offers the existing
/// spelling. The one place it decides rather than warns is a same-gym match on create,
/// which picks the existing machine (`Machine.made(for:at:named:in:)`) so one gym never
/// holds two machines with one label.
///
/// **Strength machines get no check**: the failure there is late relabelling, which no
/// creation-time warning can catch and `Merge into…` repairs (§7.5).
struct ErgModelMatch {

    /// The name as typed, trimmed.
    let typed: String

    /// This erg's machine the name looks like.
    let existing: Machine

    /// Whether `existing` sits at the gym the name is going to. On create that picks it;
    /// on rename it offers `Merge into…` it; on Move it asks to merge into it.
    let isSameGym: Bool

    /// The spelling the check offers — the existing machine's.
    var spelling: String { existing.name }

    /// *You have a Technogym Excite at FitX — same model?*
    var warning: String {
        "You have a \(existing.name) at \(gymName) — same model?"
    }

    /// Move's question, when the target gym already holds a passing machine for this
    /// erg: *FitX already has a Technogym Excite. Merge into it?*
    var moveQuestion: String {
        "\(gymName) already has a \(existing.name). Merge into it?"
    }

    private var gymName: String { existing.gym?.name ?? "no gym" }

    // MARK: - The one entry point

    /// The machine of `exercise`'s a name typed for a machine at `gym` looks like, or
    /// `nil` where there is nothing to say: a lift, a blank name, no near spelling, or a
    /// spelling that already matches another gym's exactly — converged, which is the
    /// point.
    ///
    /// **A match at `gym` itself comes first**, because there it is not a spelling to
    /// converge on but the same machine twice. `excluding` is the machine being renamed or
    /// moved, which is never its own match.
    static func check(
        _ name: String?,
        for exercise: Exercise,
        at gym: Gym?,
        excluding machine: Machine? = nil
    ) -> ErgModelMatch? {
        guard exercise.isErg, let typed = Machine.label(from: name) else { return nil }

        let candidates = MachineScope.byRecency(
            (exercise.machines ?? []).filter { $0 !== machine && model(of: $0) != nil }
        )
        let here = candidates.filter { gym != nil && $0.gym?.id == gym?.id }
        let elsewhere = candidates.filter { candidate in !here.contains { $0 === candidate } }

        if let match = here.first(where: { looksAlike(typed, $0) }) {
            return ErgModelMatch(typed: typed, existing: match, isSameGym: true)
        }
        // Already spelled exactly as another gym spells it: nothing to converge on.
        guard !elsewhere.contains(where: { model(of: $0) == typed }) else { return nil }
        guard let match = elsewhere.first(where: { looksAlike(typed, $0) }) else { return nil }
        return ErgModelMatch(typed: typed, existing: match, isSameGym: false)
    }

    /// The create doors' warning — every `New machine here`, and `Change kind`'s machine
    /// prompt: **only a match at another gym**, put to you before the machine is made. A
    /// same-gym match is not a warning but a rule, which `Machine.made` applies by
    /// picking that machine.
    static func onCreate(_ name: String?, for exercise: Exercise, at gym: Gym) -> ErgModelMatch? {
        guard let match = check(name, for: exercise, at: gym), !match.isSameGym else { return nil }
        return match
    }

    /// `Rename…`'s check on a machine row: the name typed for `machine`, checked at its
    /// own gym, never against itself. A same-gym match offers `Merge into…` that sibling
    /// (`merge(from:)`); one elsewhere offers its spelling.
    static func onRename(_ machine: Machine, to name: String) -> ErgModelMatch? {
        guard let exercise = machine.exercise else { return nil }
        return check(name, for: exercise, at: machine.gym, excluding: machine)
    }

    /// The merge a same-gym match offers — on rename *Merge into…* that sibling, on Move
    /// *Merge into it?* — ready for Merge's usual confirmation. `nil` where the match is
    /// at another gym: merging across gyms is incoherent by construction (§7.5).
    ///
    /// On Move the match is at the *target* gym, which the moving machine has not reached
    /// yet; the write for that is `GymsModel.move(_:mergingInto:)`.
    func merge(from machine: Machine) -> MachineMerge? {
        guard isSameGym, existing !== machine, existing.exercise?.id == machine.exercise?.id else {
            return nil
        }
        return MachineMerge(loser: machine, sibling: existing)
    }

    /// `Move to another gym…`'s check: **the target gym already has a passing machine for
    /// this erg** — one whose model looks like the moving machine's. Only a match *at the
    /// target* is Move's business; a spelling elsewhere was this machine's own to
    /// converge when it was named.
    ///
    /// An unlabelled machine has no model to match, so it moves without a question.
    static func onMove(_ machine: Machine, to gym: Gym) -> ErgModelMatch? {
        guard let exercise = machine.exercise, let model = model(of: machine),
              let match = check(model, for: exercise, at: gym, excluding: machine),
              match.isSameGym
        else { return nil }
        return match
    }

    /// What a machine's model is called: its label, or its make where it has no label —
    /// the name it shows, **without** the `Unlabelled` fallback, which is no model at all.
    static func model(of machine: Machine) -> String? {
        Machine.label(from: machine.label) ?? Machine.label(from: machine.manufacturer)
    }

    private static func looksAlike(_ typed: String, _ machine: Machine) -> Bool {
        guard let model = model(of: machine) else { return false }
        return GymNameMatch.looksAlike(typed, model)
    }
}

extension Machine {

    /// **The one door every new machine goes through** — the log sheets' caption, the erg
    /// detail's qualifier, and `Change kind`'s machine prompt: a machine for `exercise` at
    /// `gym`, named by the optional one-field answer.
    ///
    /// On an erg, **a name that looks like one of its machines at the same gym picks that
    /// machine instead** (SPEC §13.11), so one gym never holds two machines with one
    /// label. A match at another gym is not decided here — it is a warning the door puts
    /// to you first (`ErgModelMatch.check`), whose answer is the name passed in.
    ///
    /// The caller saves the context.
    static func made(
        for exercise: Exercise,
        at gym: Gym,
        named name: String?,
        in context: ModelContext
    ) -> Machine {
        if let match = ErgModelMatch.check(name, for: exercise, at: gym), match.isSameGym {
            return match.existing
        }
        let machine = Machine(label: Machine.label(from: name), exercise: exercise, gym: gym)
        context.insert(machine)
        return machine
    }
}
