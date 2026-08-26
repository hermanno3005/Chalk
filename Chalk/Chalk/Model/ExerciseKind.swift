import Foundation

/// Whether an exercise's load transfers between gyms.
///
/// Stored on `Exercise` as its `rawValue` rather than as the enum itself: CloudKit
/// mirroring wants a defaulted scalar attribute, and a `String` is readable in
/// `sqlite3` when a container is pulled off the device (ADR-0001).
enum ExerciseKind: String, Codable {
    case freeWeight
    case gymBound
}
