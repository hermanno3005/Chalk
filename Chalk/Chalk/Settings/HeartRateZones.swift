import Foundation

/// Your five **heart-rate zones** (ADR-0005): the four whole-bpm lower bounds of Z2 to Z5,
/// typed on Settings, strictly rising and each between 40 and 230. Z1 has no floor and Z5
/// no ceiling.
///
/// **The only way in.** The zones are one `UserDefaults` key holding four `Int`s, held per
/// device beside the store as the current gym is (ADR-0008), and nothing reads or writes
/// that key except through this value. A missing, short, out-of-order or out-of-range value
/// reads as *not yet set* — `nil` — so a damaged key gates the lookup rather than drawing a
/// wrong line.
///
/// Read live, never cached: no entry stores a zone, so moving a boundary changes every
/// reader on its next read and nothing migrates. Chalk computes no boundary — no model, no
/// age formula, no peak — and none of them is called *threshold*.
struct HeartRateZones: Equatable {

    static let key = "heartRateZones"

    /// What a typed bound may be, in bpm — the same range a logged heart rate is held to.
    static let range = 40...230

    /// The lower bounds of Z2, Z3, Z4 and Z5, in that order.
    let lowerBounds: [Int]

    /// `nil` unless there are exactly four bounds, each in `range`, each strictly higher
    /// than the one below.
    init?(lowerBounds: [Int]) {
        guard lowerBounds.count == 4,
              lowerBounds.allSatisfy(Self.range.contains),
              zip(lowerBounds, lowerBounds.dropFirst()).allSatisfy({ $0 < $1 })
        else { return nil }
        self.lowerBounds = lowerBounds
    }

    /// The zones this device holds, or `nil` while they are not yet set.
    init?(defaults: UserDefaults) {
        guard let stored = defaults.array(forKey: Self.key) as? [Int] else { return nil }
        self.init(lowerBounds: stored)
    }

    /// Writes these zones over whatever this device held. There is no way to clear them:
    /// once set, nothing that depends on them is gated again.
    func save(to defaults: UserDefaults) {
        defaults.set(lowerBounds, forKey: Self.key)
    }

    /// The zone, 1…5, a heart rate falls in. A heart rate exactly on a boundary is in the
    /// upper zone.
    func zone(of heartRate: Int) -> Int {
        1 + lowerBounds.count { heartRate >= $0 }
    }
}
