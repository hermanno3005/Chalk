import Foundation
import SwiftData

/// A place you train, with an identity independent of its name.
///
/// Deleting a gym only nullifies its machines. Cascading would reach every entry ever
/// logged there: a gym-less machine is recoverable by reassignment, deleted history is
/// not (SPEC §3).
@Model
final class Gym {
    var id: UUID = UUID()
    var name: String = ""
    var isArchived: Bool = false
    @Relationship(deleteRule: .nullify, inverse: \Machine.gym)
    var machines: [Machine]? = []

    init(id: UUID = UUID(), name: String = "", isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.isArchived = isArchived
        self.machines = []
    }
}
