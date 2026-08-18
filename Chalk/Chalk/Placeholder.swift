import Foundation
import SwiftData

/// Throwaway model so the skeleton has a real SwiftData store to open on device.
/// The actual domain model — Exercise, Record, Gym, Machine — is settled by
/// https://github.com/hermanno3005/Chalk/issues/9 and replaces this wholesale.
///
/// Written to the CloudKit-shaped rules already: every attribute optional or
/// defaulted, no `.unique`.
@Model
final class Placeholder {
    var createdAt: Date = Date.distantPast

    init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }
}
