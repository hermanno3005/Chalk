import Foundation
import SwiftData
import Testing

@testable import Chalk

/// Onboarding (SPEC §15.3): one screen, the weight unit, the distance unit and a quieter
/// *Restore from a backup*. **It shows only while no units are stored**, so picking or
/// restoring ends it for good, and an install from before units, which the launch gives
/// kg and km, never sees it.
@Suite("Onboarding")
struct OnboardingTests {

    // MARK: - When it shows

    @Test("A fresh install shows onboarding")
    func aFreshInstallShowsOnboarding() throws {
        let fixture = try LibraryFixture()

        _ = fixture.libraryModel()

        #expect(OnboardingModel.isShown(defaults: fixture.defaults, context: fixture.context))
    }

    @Test("Picking stores both units, and onboarding never shows again, even once the library is emptied")
    func pickingEndsOnboardingForGood() throws {
        let fixture = try LibraryFixture()
        _ = fixture.libraryModel()
        let onboarding = fixture.onboardingModel()

        onboarding.weightUnit = .lb
        onboarding.distanceUnit = .mi
        onboarding.pick()

        #expect(onboarding.unitsStored)
        #expect(WeightUnit.stored(in: fixture.defaults) == .lb)
        #expect(DistanceUnit.stored(in: fixture.defaults) == .mi)
        let squat = fixture.exercise("Squat")
        try fixture.save()
        fixture.context.delete(squat)
        try fixture.save()
        _ = fixture.libraryModel()
        #expect(!OnboardingModel.isShown(defaults: fixture.defaults, context: fixture.context))
    }

    @Test("Onboarding opens on kg and km, and picking them stores them")
    func onboardingOpensOnKilogramsAndKilometres() throws {
        let fixture = try LibraryFixture()
        let onboarding = fixture.onboardingModel()

        #expect(onboarding.weightUnit == .kg)
        #expect(onboarding.distanceUnit == .km)
        onboarding.pick()

        #expect(WeightUnit.stored(in: fixture.defaults) == .kg)
        #expect(DistanceUnit.stored(in: fixture.defaults) == .km)
    }

    @Test("An install with no units stored, over a library that isn't empty, never sees onboarding and lands on kg and km")
    func anInstallFromBeforeUnitsNeverSeesOnboarding() throws {
        let fixture = try LibraryFixture()
        fixture.exercise("Squat")
        try fixture.save()

        _ = fixture.libraryModel()

        #expect(!OnboardingModel.isShown(defaults: fixture.defaults, context: fixture.context))
        #expect(WeightUnit.stored(in: fixture.defaults) == .kg)
        #expect(DistanceUnit.stored(in: fixture.defaults) == .km)
    }

    @Test("A library that isn't empty never opens on onboarding, even with no units stored")
    func aLibraryThatIsNotEmptyNeverOpensOnOnboarding() throws {
        let fixture = try LibraryFixture()
        fixture.gym("Fitness X")
        try fixture.save()

        #expect(!OnboardingModel.isShown(defaults: fixture.defaults, context: fixture.context))
    }

    // MARK: - Restore from a backup

    @Test("Restoring from onboarding lands on the restored library with the backup's units")
    func restoringTakesTheBackupsUnits() throws {
        let fixture = try LibraryFixture()
        _ = fixture.libraryModel()
        let onboarding = fixture.onboardingModel()
        let file = try RestoreTests.fixedLibraryFile { json in
            var settings = json["settings"] as? [String: Any] ?? [:]
            settings["weightUnit"] = "lb"
            settings["distanceUnit"] = "mi"
            json["settings"] = settings
        }

        onboarding.restore(file)

        #expect(onboarding.restoreConfirmation == nil)
        #expect(onboarding.unitsStored)
        #expect(WeightUnit.stored(in: fixture.defaults) == .lb)
        #expect(DistanceUnit.stored(in: fixture.defaults) == .mi)
        #expect(try fixture.afterRelaunch().fetchCount(FetchDescriptor<Exercise>()) == 5)
        #expect(!OnboardingModel.isShown(defaults: fixture.defaults, context: fixture.context))
    }

    @Test("A file Chalk can't restore is refused in its plain words, and onboarding stays")
    func aRefusedFileKeepsOnboarding() throws {
        let fixture = try LibraryFixture()
        _ = fixture.libraryModel()
        let onboarding = fixture.onboardingModel()

        onboarding.restore(Data("Bench Press 5 × 57.5".utf8))

        #expect(onboarding.restoreFailure == Backup.Refusal.notABackup.message)
        #expect(!onboarding.unitsStored)
        #expect(OnboardingModel.isShown(defaults: fixture.defaults, context: fixture.context))
    }
}
