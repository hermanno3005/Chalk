import Foundation
import SwiftData

/// A user-owned, ordered bucket an exercise may sit in. Named `ExerciseGroup` to leave
/// SwiftUI's `Group` view alone.
///
/// `sortIndex` is a real field rather than array position: relationship arrays are not
/// order-preserving when mirrored. Deleting a group only nullifies — its exercises fall
/// back to Ungrouped (SPEC §3).
@Model
final class ExerciseGroup {
    var id: UUID = UUID()
    var name: String = ""
    var sortIndex: Int = 0
    @Relationship(deleteRule: .nullify, inverse: \Exercise.group)
    var exercises: [Exercise]? = []

    init(id: UUID = UUID(), name: String = "", sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
        self.exercises = []
    }
}
