import Foundation
import SwiftData
import Testing

@testable import Chalk

/// Settings (ADR-0005): Chalk's one settings screen, holding the heart-rate zones, and
/// where a backup is made and restored (ADR-0010). Four lower bounds, Z2 to Z5; a save
/// needs all four, each 40–230 bpm and strictly rising; once saved they can be edited and
/// never cleared from here.
@Suite("Settings model")
struct SettingsModelTests {

    // MARK: - Opening

    @Test("Settings opens blank, and can't save, before zones are set")
    func opensBlankBeforeZonesAreSet() throws {
        let fixture = try LibraryFixture()

        let settings = fixture.settingsModel()

        #expect(settings.lowerBounds == [nil, nil, nil, nil])
        #expect(!settings.canSave)
    }

    @Test("Settings opens on the zones already saved")
    func opensOnTheSavedZones() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)

        let settings = fixture.settingsModel()

        #expect(settings.lowerBounds == [117, 140, 158, 170])
    }

    // MARK: - Save

    @Test("Save needs all four bounds")
    func saveNeedsAllFour() throws {
        let fixture = try LibraryFixture()
        let settings = fixture.settingsModel()

        settings.lowerBounds = [117, 140, 158, nil]
        #expect(!settings.canSave)

        settings.lowerBounds = [117, 140, 158, 170]
        #expect(settings.canSave)
    }

    @Test("Save needs each bound in 40–230 bpm and strictly higher than the one below", arguments: [
        [39, 140, 158, 170],
        [117, 140, 158, 231],
        [117, 140, 140, 170],
        [117, 158, 140, 170],
    ])
    func saveNeedsAValidSet(bounds: [Int]) throws {
        let fixture = try LibraryFixture()
        let settings = fixture.settingsModel()

        settings.lowerBounds = bounds

        #expect(!settings.canSave)
    }

    @Test("Saving sets the zones every reader sees")
    func savingSetsTheZones() throws {
        let fixture = try LibraryFixture()
        let settings = fixture.settingsModel()

        settings.lowerBounds = [117, 140, 158, 170]
        settings.save()

        #expect(fixture.heldZones()?.lowerBounds == [117, 140, 158, 170])
    }

    @Test("Saved zones can be edited")
    func savedZonesCanBeEdited() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let settings = fixture.settingsModel()

        settings.lowerBounds[2] = 160
        settings.save()

        #expect(fixture.heldZones()?.lowerBounds == [117, 140, 160, 170])
    }

    @Test("Saved zones can't be cleared")
    func savedZonesCannotBeCleared() throws {
        let fixture = try LibraryFixture()
        fixture.zones(117, 140, 158, 170)
        let settings = fixture.settingsModel()

        settings.lowerBounds = [nil, nil, nil, nil]
        #expect(!settings.canSave)
        settings.save()

        #expect(fixture.heldZones()?.lowerBounds == [117, 140, 158, 170])
    }

    @Test("An invalid set is never saved, whatever calls save")
    func anInvalidSetIsNeverSaved() throws {
        let fixture = try LibraryFixture()
        let settings = fixture.settingsModel()

        settings.lowerBounds = [117, 158, 140, 170]
        settings.save()

        #expect(fixture.heldZones() == nil)
    }

    // MARK: - Restore

    @Test("Over a library holding only its seeded groups and zones, a picked backup restores without asking")
    func restoresAnEmptyLibraryWithoutAsking() throws {
        let fixture = try LibraryFixture()
        fixture.zones(110, 130, 150, 165)
        let settings = fixture.settingsModel()

        settings.restore(try RestoreTests.fixedLibraryFile())

        #expect(settings.restoreConfirmation == nil)
        #expect(settings.restored)
        #expect(try fixture.afterRelaunch().fetchCount(FetchDescriptor<Exercise>()) == 5)
    }

    @Test("Over a library that is not empty, it asks first and changes nothing until confirmed")
    func asksBeforeReplacingALibrary() throws {
        let fixture = try LibraryFixture()
        try RestoreTests.differentLibrary(in: fixture)
        let settings = fixture.settingsModel()
        let before = try RestoreTests.snapshot(of: fixture)

        settings.restore(try RestoreTests.fixedLibraryFile())

        #expect(settings.restoreConfirmation?.hasPrefix("This replaces 3 entries with 8 from ") == true)
        #expect(!settings.restored)
        #expect(try RestoreTests.snapshot(of: fixture) == before)

        settings.confirmRestore()

        #expect(settings.restoreConfirmation == nil)
        #expect(settings.restored)
        #expect(try fixture.afterRelaunch().fetchCount(FetchDescriptor<Exercise>()) == 5)
    }

    @Test("Cancelling the question changes nothing")
    func cancellingARestoreChangesNothing() throws {
        let fixture = try LibraryFixture()
        try RestoreTests.differentLibrary(in: fixture)
        let settings = fixture.settingsModel()
        let before = try RestoreTests.snapshot(of: fixture)

        settings.restore(try RestoreTests.fixedLibraryFile())
        settings.cancelRestore()
        settings.confirmRestore()

        #expect(settings.restoreConfirmation == nil)
        #expect(!settings.restored)
        #expect(try RestoreTests.snapshot(of: fixture) == before)
    }

    @Test("A file Chalk can't restore is refused in its plain words, with nothing changed")
    func aRefusedFileSaysWhy() throws {
        let fixture = try LibraryFixture()
        try RestoreTests.differentLibrary(in: fixture)
        let settings = fixture.settingsModel()
        let before = try RestoreTests.snapshot(of: fixture)

        settings.restore(Data("Bench Press 5 × 57.5".utf8))

        #expect(settings.restoreFailure == Backup.Refusal.notABackup.message)
        #expect(settings.restoreConfirmation == nil)
        #expect(!settings.restored)
        #expect(try RestoreTests.snapshot(of: fixture) == before)
    }
}
