import Foundation
import Observation
import SwiftData

/// The groups, and the four verbs Edit groups offers — **reorder, rename, delete, add**
/// (SPEC §7.2).
///
/// Groups are **user-owned ordered buckets, not a taxonomy**, and a user-owned thing you
/// cannot rename, reorder or delete is not actually user-owned. So the suggestion Chalk
/// seeds is only ever a suggestion: past first launch these are ordinary rows, and no
/// screen falls back to the shipped list.
///
/// **Reordering is the primary verb, not an afterthought** — this list's order *is* the
/// section order on the library screen, which is the whole of "compounds at the top".
///
/// Held by `LibraryModel`, which wires `onChange` to its own refresh so the grid behind
/// the sheet moves with it.
@Observable
final class GroupsModel {

    /// Every group, in the user's own order — including the ones holding nothing, which
    /// the grid leaves out but the group picker must still offer.
    private(set) var groups: [ExerciseGroup] = []

    /// What to put back in step after a mutation — the library grid behind the sheet.
    /// Assigned after `init` rather than taken as a parameter, because the owner cannot
    /// capture itself while its own stored properties are still being initialised.
    @ObservationIgnored var onChange: () -> Void = {}

    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        refresh()
    }

    /// Creates a group at the end of the order and returns it.
    ///
    /// Returns `nil` for a name that is blank once trimmed. Nothing else can fail: two
    /// groups may share a name, because this is a shelf rather than a classification and
    /// nothing downstream resolves a group by what it is called.
    @discardableResult
    func create(named name: String) -> ExerciseGroup? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        // Past the current maximum rather than `groups.count`, so a store whose indices
        // are not dense — one arriving from another device — cannot collide.
        let last = groups.map(\.sortIndex).max() ?? -1
        let group = ExerciseGroup(name: name, sortIndex: last + 1)
        context.insert(group)
        save()
        return group
    }

    /// Renames a group. Identity is `ExerciseGroup.id`, so this costs the exercises on it
    /// nothing — as with a gym, the name is only what it is called.
    ///
    /// A blank name leaves it alone: an empty section header is not a rename anyone meant.
    func rename(_ group: ExerciseGroup, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        group.name = name
        save()
    }

    /// Deletes a group. **Its exercises fall back to Ungrouped and nothing else goes** —
    /// the relationship's delete rule is `.nullify` (SPEC §3), so removing a shelf never
    /// removes what was on it.
    ///
    /// The remaining groups keep their indices, gaps and all: order is what `sortIndex`
    /// is for, and a gap does not change one.
    func delete(_ group: ExerciseGroup) {
        context.delete(group)
        save()
    }

    /// Moves groups within the order — the sheet's `onMove`, and the library's section
    /// order changing.
    ///
    /// **Renumbers every group densely from the array's new positions.** `sortIndex` is a
    /// real field rather than array position precisely because relationship arrays are not
    /// order-preserving when mirrored (SPEC §3), so a move is only real once it is
    /// written back.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var moved = groups
        moved.move(fromOffsets: source, toOffset: destination)
        for (index, group) in moved.enumerated() where group.sortIndex != index {
            group.sortIndex = index
        }
        save()
    }

    /// Re-reads the groups. Called at init, and by `LibraryModel.refresh()` — anything
    /// that edits a group behind the grid comes back through here.
    func refresh() {
        groups = GroupOrder.inOrder((try? context.fetch(FetchDescriptor<ExerciseGroup>())) ?? [])
    }

    /// As everywhere else: v1 has no error state past §3's container failure and no
    /// network, so there is nothing here to report and nothing to retry — the change
    /// stays in the context either way and the next save takes it with it.
    private func save() {
        try? context.save()
        refresh()
        onChange()
    }
}
