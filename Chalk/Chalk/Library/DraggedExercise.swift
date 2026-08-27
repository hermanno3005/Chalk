import CoreTransferable
import Foundation

/// What a dragged tile carries: **an exercise's id, never the exercise** (SPEC §7.2).
///
/// A SwiftData `PersistentModel` is not `Transferable`, and should not be made one: the
/// payload is archived at the pick-up and handed back at the drop, so anything that
/// arrived that way would be a detached copy of a row the store still owns. The drop
/// looks the id back up in the store instead.
///
/// It travels as a plain UUID string. The cost of a system representation rather than a
/// private one is that a section will accept text dragged in from another app — which
/// then resolves to no exercise and is refused, one line at the drop. The benefit is that
/// there is no custom `UTType` to declare in an Info.plist and keep in step.
struct DraggedExercise: Codable, Transferable {

    /// `nil` for a payload that was not one of ours — text from another app. A drop that
    /// finds one of these files nothing rather than guessing.
    let id: UUID?

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(
            exporting: { (dragged: DraggedExercise) in dragged.id?.uuidString ?? "" },
            importing: { (text: String) in DraggedExercise(id: UUID(uuidString: text)) }
        )
    }
}
