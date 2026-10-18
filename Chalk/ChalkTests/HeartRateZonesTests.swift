import Foundation
import Testing

@testable import Chalk

/// The heart-rate zones (ADR-0005): four typed lower bounds, Z2 to Z5, read from one
/// `UserDefaults` key through `HeartRateZones` and nothing else. Each test reads a suite of
/// its own, never the running app's defaults.
@Suite("Heart-rate zones")
final class HeartRateZonesTests {

    private let suiteName = "chalk-zones-tests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Not yet set

    @Test("No stored value reads as not yet set")
    func absentIsNotSet() {
        #expect(HeartRateZones(defaults: defaults) == nil)
    }

    @Test("Three bounds read as not yet set")
    func threeBoundsAreNotSet() {
        defaults.set([117, 140, 158], forKey: HeartRateZones.key)

        #expect(HeartRateZones(defaults: defaults) == nil)
    }

    @Test("Five bounds read as not yet set")
    func fiveBoundsAreNotSet() {
        defaults.set([100, 117, 140, 158, 170], forKey: HeartRateZones.key)

        #expect(HeartRateZones(defaults: defaults) == nil)
    }

    @Test("Bounds that don't strictly rise read as not yet set", arguments: [
        [140, 117, 158, 170],
        [117, 140, 170, 158],
        [117, 140, 140, 170],
    ])
    func outOfOrderIsNotSet(bounds: [Int]) {
        defaults.set(bounds, forKey: HeartRateZones.key)

        #expect(HeartRateZones(defaults: defaults) == nil)
    }

    @Test("A bound outside 40–230 bpm reads as not yet set", arguments: [
        [39, 140, 158, 170],
        [117, 140, 158, 231],
    ])
    func outOfRangeIsNotSet(bounds: [Int]) {
        defaults.set(bounds, forKey: HeartRateZones.key)

        #expect(HeartRateZones(defaults: defaults) == nil)
    }

    @Test("A value that isn't four whole numbers reads as not yet set")
    func aForeignValueIsNotSet() {
        defaults.set("117,140,158,170", forKey: HeartRateZones.key)

        #expect(HeartRateZones(defaults: defaults) == nil)
    }

    // MARK: - Set

    @Test("Four rising bounds read as zones")
    func fourRisingBoundsAreZones() throws {
        defaults.set([117, 140, 158, 170], forKey: HeartRateZones.key)

        let zones = try #require(HeartRateZones(defaults: defaults))

        #expect(zones.lowerBounds == [117, 140, 158, 170])
    }

    @Test("The bounds may sit on 40 and 230 bpm")
    func theRangeIsInclusive() {
        defaults.set([40, 41, 229, 230], forKey: HeartRateZones.key)

        #expect(HeartRateZones(defaults: defaults)?.lowerBounds == [40, 41, 229, 230])
    }

    @Test("Saved zones read back as themselves")
    func savedZonesReadBack() throws {
        let zones = try #require(HeartRateZones(lowerBounds: [117, 140, 158, 170]))

        zones.save(to: defaults)

        #expect(HeartRateZones(defaults: defaults) == zones)
    }

    // MARK: - Zone of a heart rate

    @Test("A heart rate on a boundary is in the upper zone, either side of it in its own", arguments: [
        (116, 1), (117, 2), (118, 2),
        (139, 2), (140, 3), (141, 3),
        (157, 3), (158, 4), (159, 4),
        (169, 4), (170, 5), (171, 5),
    ])
    func zoneOfAHeartRate(heartRate: Int, zone: Int) throws {
        let zones = try #require(HeartRateZones(lowerBounds: [117, 140, 158, 170]))

        #expect(zones.zone(of: heartRate) == zone)
    }

    @Test("Z1 has no floor and Z5 no ceiling")
    func theOuterZonesAreOpen() throws {
        let zones = try #require(HeartRateZones(lowerBounds: [117, 140, 158, 170]))

        #expect(zones.zone(of: 40) == 1)
        #expect(zones.zone(of: 230) == 5)
    }
}
