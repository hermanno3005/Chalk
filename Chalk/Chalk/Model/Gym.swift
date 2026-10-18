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

    /// When you last trained here — a lift or a valid interval, across every machine
    /// this gym holds. `nil` for a gym you have never logged at — a freshly created one,
    /// or one whose machines are empty.
    ///
    /// This is the whole of gym ordering (SPEC §7.4): it is derived from the entries, so
    /// there is no index to store and nothing to keep up to date. **Both halves count**,
    /// so a gym you visit only for endurance does not sink (SPEC §13.12) — but only what
    /// you did: a zeroed row is neither a lift nor an interval (SPEC §3). A transferable
    /// erg's intervals hang off no machine, so they count toward no gym, as a free-weight
    /// lift's do not.
    var lastLogged: Date? {
        (machines ?? []).compactMap(\.lastLogged).max()
    }

    init(id: UUID = UUID(), name: String = "", isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.isArchived = isArchived
        self.machines = []
    }
}
