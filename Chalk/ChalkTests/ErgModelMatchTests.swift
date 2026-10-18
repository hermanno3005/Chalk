import Foundation
import SwiftData
import Testing

@testable import Chalk

/// The near-name check on erg machines (SPEC §7.5, §13.11, #117) — gym creation's loose
/// matching, run **against that erg's machines at every gym**, on create, `Rename…` and
/// Move.
///
/// What an implementer gets wrong: **it warns and never blocks** — it only ever offers the
/// existing spelling — except in the one case the spec makes a rule rather than a warning:
/// **a same-gym match on create picks the existing machine**, so one gym never holds two
/// machines with one label. And **strength machines get no check at all**: late
/// relabelling is what Merge is for (§7.5).
@Suite("Erg model near-name check")
struct ErgModelMatchTests {

    // MARK: - The check

    @Test("A near spelling of this erg's machine at another gym warns, offering the existing spelling")
    func aNearSpellingAtAnotherGymWarns() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let fitX = fixture.gym("FitX")
        let urban = fixture.gym("Urban Gym")
        fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")

        let match = try #require(ErgModelMatch.check("technogym exite", for: treadmill, at: urban))

        #expect(match.isSameGym == false)
        #expect(match.spelling == "Technogym Excite")
        #expect(match.warning == "You have a Technogym Excite at FitX — same model?")
    }

    @Test("Strength machines get no near-name check")
    func strengthMachinesGetNoCheck() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let fitX = fixture.gym("FitX")
        let urban = fixture.gym("Urban Gym")
        fixture.machine(for: legPress, at: fitX, label: "Hammer Strength")

        #expect(ErgModelMatch.check("hammer strenght", for: legPress, at: urban) == nil)
        #expect(ErgModelMatch.check("Hammer Strength", for: legPress, at: fitX) == nil)
    }

    @Test("Only this erg's machines are checked, never another erg's")
    func onlyThisErgsMachinesAreChecked() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let bike = fixture.erg("Bike", unit: .watts)
        let fitX = fixture.gym("FitX")
        fixture.machine(for: bike, at: fitX, label: "Technogym Excite")

        #expect(ErgModelMatch.check("Technogym Excite", for: treadmill, at: fixture.gym("Urban Gym")) == nil)
    }

    @Test("A spelling that already matches another gym's exactly has nothing to converge on")
    func anExactSpellingElsewhereDoesNotWarn() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Technogym Excite")

        #expect(ErgModelMatch.check(" Technogym Excite ", for: treadmill, at: fixture.gym("Urban Gym")) == nil)
    }

    @Test("A blank name, a far name and an unlabelled machine raise nothing")
    func nothingToMatchRaisesNothing() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let fitX = fixture.gym("FitX")
        fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")
        fixture.machine(for: treadmill, at: fitX)
        let urban = fixture.gym("Urban Gym")

        #expect(ErgModelMatch.check(nil, for: treadmill, at: urban) == nil)
        #expect(ErgModelMatch.check("   ", for: treadmill, at: urban) == nil)
        #expect(ErgModelMatch.check("Matrix T7", for: treadmill, at: urban) == nil)
        // An unlabelled machine has no model to converge on.
        #expect(ErgModelMatch.check("Unlabelled", for: treadmill, at: urban) == nil)
    }

    @Test("A match at the same gym is preferred over one elsewhere")
    func aSameGymMatchIsPreferred() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let fitX = fixture.gym("FitX")
        let urban = fixture.gym("Urban Gym")
        fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")
        let here = fixture.machine(for: treadmill, at: urban, label: "TechnoGym Excite")

        let match = try #require(ErgModelMatch.check("technogym excite", for: treadmill, at: urban))

        #expect(match.isSameGym)
        #expect(match.existing === here)
        #expect(match.warning == "You have a TechnoGym Excite at Urban Gym — same model?")
    }

    // MARK: - On create

    @Test("On create, a near spelling at another gym warns before the machine is made")
    func createWarnsOnANearSpellingElsewhere() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Technogym Excite")
        let urban = fixture.gym("Urban Gym")
        try fixture.save()

        let model = fixture.lapListModel(for: treadmill)

        let match = try #require(model.nearModel(named: "technogym exite", at: urban))
        #expect(match.warning == "You have a Technogym Excite at FitX — same model?")
        // A warning, never a block: either spelling makes the machine.
        model.createMachine(at: urban, named: match.spelling)
        #expect(model.machineCaption == "Technogym Excite · Urban Gym")
        #expect(treadmill.machines?.count == 2)
    }

    @Test("On create, a near spelling at the same gym picks the existing machine")
    func createAtTheSameGymPicksTheExistingMachine() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let urban = fixture.gym("Urban Gym")
        let excite = fixture.machine(for: treadmill, at: urban, label: "Technogym Excite")
        try fixture.save()

        let model = fixture.lapListModel(for: treadmill)
        // Nothing to warn about: the rule decides.
        #expect(model.nearModel(named: "technogym exite", at: urban) == nil)

        model.createMachine(at: urban, named: "technogym exite")

        #expect(model.machine === excite)
        #expect(model.machineCaption == "Technogym Excite · Urban Gym")
        // One gym never holds two machines with one label.
        #expect(treadmill.machines?.count == 1)
    }

    @Test("On create, a strength machine is made as typed with no warning, same gym or not")
    func strengthCreateIsUnchecked() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("Fitness X")
        fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        try fixture.save()

        let model = fixture.logSheetModel(for: legPress)
        #expect(model.nearModel(named: "hammer strength", at: gym) == nil)
        model.createMachine(at: gym, named: "hammer strength")

        #expect(model.machineCaption == "hammer strength · Fitness X")
        #expect(legPress.machines?.count == 2)
    }

    // MARK: - On rename

    @Test("On rename, a near spelling at another gym warns and offers no merge")
    func renameWarnsOnANearSpellingElsewhere() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Technogym Excite")
        let mine = fixture.machine(for: treadmill, at: fixture.gym("Urban Gym"))

        let match = try #require(ErgModelMatch.onRename(mine, to: "Technogym Excte"))

        #expect(match.warning == "You have a Technogym Excite at FitX — same model?")
        // Merging across gyms is incoherent by construction.
        #expect(match.merge(from: mine) == nil)
    }

    @Test("On rename, a same-gym match offers Merge into that sibling, with Merge's confirmation")
    func renameOffersMergeIntoASameGymSibling() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let gym = fixture.gym("FitX")
        let sibling = fixture.machine(for: treadmill, at: gym, label: "Technogym Excite")
        let mine = fixture.machine(for: treadmill, at: gym)
        fixture.interval(treadmill, machine: mine, on: .days(ago: 3))
        fixture.interval(treadmill, machine: mine, on: .days(ago: 2))
        fixture.interval(treadmill, machine: sibling, on: .days(ago: 1))
        try fixture.save()

        let match = try #require(ErgModelMatch.onRename(mine, to: "technogym excite"))
        #expect(match.isSameGym)
        let merge = try #require(match.merge(from: mine))
        #expect(merge.sibling === sibling)
        #expect(merge.question == "Move 2 entries to Technogym Excite and delete Unlabelled?")

        fixture.gymsModel().merge(merge.loser, into: merge.sibling)
        #expect(treadmill.machines?.count == 1)
        #expect(sibling.entries?.count == 3)
    }

    @Test("Renaming a machine to its own model raises nothing — it is never its own match")
    func renameNeverMatchesItself() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let mine = fixture.machine(for: treadmill, at: fixture.gym("FitX"), label: "Technogym Excite")

        #expect(ErgModelMatch.onRename(mine, to: "Technogym Excite Run") == nil)
    }

    @Test("On rename, a strength machine gets no warning and no merge offer")
    func strengthRenameIsUnchecked() throws {
        let fixture = try LibraryFixture()
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let gym = fixture.gym("FitX")
        fixture.machine(for: legPress, at: gym, label: "Hammer Strength")
        let mine = fixture.machine(for: legPress, at: gym)

        #expect(ErgModelMatch.onRename(mine, to: "Hammer Strength") == nil)
    }

    // MARK: - On Move

    @Test("On Move, a passing machine at the target asks to merge into it")
    func moveAsksWhenTheTargetHasAPassingMachine() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let fitX = fixture.gym("FitX")
        let theirs = fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")
        let mine = fixture.machine(for: treadmill, at: fixture.gym("FitX Mitte"), label: "Technogym excite")

        let match = try #require(ErgModelMatch.onMove(mine, to: fitX))

        #expect(match.existing === theirs)
        #expect(match.moveQuestion == "FitX already has a Technogym Excite. Merge into it?")
    }

    @Test("Move asks nothing where the target has no passing machine, or for a lift")
    func moveAsksNothingOtherwise() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let legPress = fixture.exercise("Leg Press", kind: .gymBound)
        let fitX = fixture.gym("FitX")
        let urban = fixture.gym("Urban Gym")
        fixture.machine(for: treadmill, at: fitX, label: "Matrix T7")
        fixture.machine(for: legPress, at: fitX, label: "Hammer Strength")
        let tread = fixture.machine(for: treadmill, at: urban, label: "Technogym Excite")
        let press = fixture.machine(for: legPress, at: urban, label: "Hammer Strength")
        // A passing machine at a gym that is not the target is not Move's business.
        fixture.machine(for: treadmill, at: fixture.gym("Old Barn"), label: "Technogym Excite")

        #expect(ErgModelMatch.onMove(tread, to: fitX) == nil)
        #expect(ErgModelMatch.onMove(press, to: fitX) == nil)
    }

    @Test("Move's Merge pools the entries onto the target's machine; Move anyway keeps both")
    func moveMergeOrMoveAnyway() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let fitX = fixture.gym("FitX")
        let mitte = fixture.gym("FitX Mitte")
        let theirs = fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")
        let mine = fixture.machine(for: treadmill, at: mitte, label: "Technogym excite")
        let other = fixture.machine(for: treadmill, at: mitte, label: "Technogym Excite Run")
        fixture.interval(treadmill, machine: theirs, incline: 0, on: .days(ago: 4))
        fixture.interval(treadmill, machine: mine, incline: 2, on: .days(ago: 3))
        fixture.interval(treadmill, machine: other, incline: 1, on: .days(ago: 2))
        try fixture.save()
        let gyms = fixture.gymsModel()

        // Merge, after Merge's confirmation — which names both gyms, since the two
        // machines may well share a name.
        let match = try #require(ErgModelMatch.onMove(mine, to: fitX))
        let merge = try #require(match.merge(from: mine))
        #expect(merge.question == "Move 1 entry to Technogym Excite · FitX and delete Technogym excite · FitX Mitte?")
        gyms.move(merge.loser, mergingInto: merge.sibling)

        // Move anyway: the machine simply moves, as any Move.
        let anyway = try #require(ErgModelMatch.onMove(other, to: fitX))
        #expect(anyway.existing === theirs)
        gyms.move(other, to: fitX)

        let reopened = try fixture.afterRelaunch()
        let machines = try reopened.fetch(FetchDescriptor<Machine>())
        #expect(machines.map(\.name).sorted() == ["Technogym Excite", "Technogym Excite Run"])
        #expect(machines.allSatisfy { $0.gym?.name == "FitX" })
        let survivor = try #require(machines.first { $0.id == theirs.id })
        // Incline moves with its entries.
        #expect(survivor.entries?.compactMap(\.incline).sorted() == [0, 2])
        #expect(try reopened.fetch(FetchDescriptor<Entry>()).count == 3)
    }

    @Test("The erg detail's qualifier offers New machine here, checked the same way")
    func theQualifierCreatesThroughTheSameCheck() throws {
        let fixture = try LibraryFixture()
        let treadmill = fixture.erg("Treadmill")
        let urban = fixture.gym("Urban Gym")
        let fitX = fixture.gym("FitX")
        let excite = fixture.machine(for: treadmill, at: fitX, label: "Technogym Excite")
        fixture.interval(treadmill, machine: excite, on: .days(ago: 3))
        try fixture.save()
        let gyms = fixture.gymsModel()
        gyms.select(urban)

        let model = fixture.ergDetailModel(for: treadmill, gyms: gyms)
        // The gym you are standing in has a section to make one in.
        #expect(model.machineMenu.sections.map(\.title) == ["Urban Gym", "FitX"])
        #expect(model.nearModel(named: "Technogym Excit", at: urban)?.spelling == "Technogym Excite")

        model.createMachine(at: urban, named: "Technogym Excite")
        #expect(model.machine?.caption == "Technogym Excite · Urban Gym")

        // A second create at the same gym lands on that one rather than a twin.
        model.createMachine(at: urban, named: "technogym excite")
        #expect(treadmill.machines?.count == 2)
        #expect(model.machine?.caption == "Technogym Excite · Urban Gym")
    }
}
