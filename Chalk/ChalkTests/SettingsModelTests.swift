import Foundation
import Testing

@testable import Chalk

/// Settings (ADR-0005): Chalk's one settings screen, holding the heart-rate zones and
/// nothing else. Four lower bounds, Z2 to Z5; a save needs all four, each 40–230 bpm and
/// strictly rising; once saved they can be edited and never cleared.
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
}
