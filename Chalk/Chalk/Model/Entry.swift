import Foundation
import SwiftData

/// One logged performance — a lift or an interval — and the moment it was logged. The
/// only thing Chalk stores about your training.
///
/// **One entity for both halves** (ADR-0008): a lift fills `reps` and `weight`, an
/// interval fills `duration`, `intensity`, both heart rates and (on a speed erg)
/// `incline`, and each leaves the other half's fields at their defaults. `isALift` and
/// `isAnInterval` are what every reader asks, so a half-filled row never reaches the
/// wrong half's derivation.
///
/// `reps >= 1`, `weight > 0` and an interval's required fields are app-level guards, not
/// schema rules — every attribute here is defaulted so the schema stays CloudKit-shaped
/// (ADR-0001). An entry with a nil `exercise` is treated as non-existent (SPEC §3).
@Model
final class Entry {
    var id: UUID = UUID()
    /// >= 1, no upper bound.
    var reps: Int = 0
    /// Kilograms, always. > 0.
    var weight: Double = 0
    /// Whole seconds, exactly as typed and never snapped. > 0 on an interval.
    var duration: Int = 0
    /// In the erg's unit, exactly as typed and never converted — a split as seconds per
    /// 500 m. > 0 on an interval. Compared only in whole steps of its unit (`ErgUnit`).
    var intensity: Double = 0
    /// Percent, read on a speed erg only. 0 % is a real value, not a blank.
    var incline: Double = 0
    /// Whole bpm. What an interval's effort is read by. Set on every interval.
    var averageHeartRate: Int = 0
    /// Whole bpm, never below the average. Required at write time, never read by the
    /// derivation.
    var peakHeartRate: Int = 0
    /// Immutable after creation.
    var date: Date = Date.now
    /// Always set in practice.
    var exercise: Exercise?
    /// Gym-bound exercises and ergs only.
    var machine: Machine?

    /// Whether this row is a lift: `reps >= 1` and `weight > 0`.
    ///
    /// The guard is app-level, not a schema rule — every attribute here is defaulted to
    /// keep the schema CloudKit-shaped (ADR-0001), so a zeroed row is representable even
    /// though SPEC §3's write-time guards reject one. It is not a lift, it does not
    /// derive, and it never seeds the log sheet. No interval is a lift, so every lift
    /// reader ignores intervals with no change.
    var isALift: Bool { reps >= 1 && weight > 0 }

    /// Whether this row is a **valid interval**, the endurance twin of `isALift`:
    /// `duration > 0`, `intensity > 0` and an average heart rate set (ADR-0008).
    ///
    /// Read wherever recency, seeding or the derivation reads an interval. Peak and
    /// incline are not part of it: incline is legitimately 0 %, and the zone line never
    /// reads peak. No lift is an interval.
    var isAnInterval: Bool { duration > 0 && intensity > 0 && averageHeartRate > 0 }

    init(
        id: UUID = UUID(),
        reps: Int = 0,
        weight: Double = 0,
        duration: Int = 0,
        intensity: Double = 0,
        incline: Double = 0,
        averageHeartRate: Int = 0,
        peakHeartRate: Int = 0,
        date: Date = .now,
        exercise: Exercise? = nil,
        machine: Machine? = nil
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.intensity = intensity
        self.incline = incline
        self.averageHeartRate = averageHeartRate
        self.peakHeartRate = peakHeartRate
        self.date = date
        self.exercise = exercise
        self.machine = machine
    }
}
