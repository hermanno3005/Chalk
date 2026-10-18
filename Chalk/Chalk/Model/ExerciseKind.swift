import Foundation

/// Whether an exercise's or erg's numbers transfer between gyms.
///
/// **`freeWeight` is free-weight on a lift, transferable on an erg** (ADR-0008): both
/// mean *derive across every gym, with no machines*, so a transferable erg stores
/// `freeWeight`, raw value and Swift case alike. Code reads `isGymBound` in both halves,
/// so the strength word surfaces only where a raw `kind` is read. Renaming the case would
/// have strength code call a barbell transferable, and renaming the raw value would need
/// a migration stage that rewrites rows.
///
/// Stored on `Exercise` as its `rawValue` rather than as the enum itself: CloudKit
/// mirroring wants a defaulted scalar attribute, and a `String` is readable in
/// `sqlite3` when a container is pulled off the device (ADR-0001).
enum ExerciseKind: String, Codable {
    case freeWeight
    case gymBound
}
