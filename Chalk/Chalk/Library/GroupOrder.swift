import Foundation

/// The order groups are drawn in: **`sortIndex`, the arrangement you made yourself**
/// (SPEC §7.2).
///
/// The one rule, in one place, because two screens read it and they must not drift: the
/// library's sections *are* this order, and Edit groups is the list you rearrange it in.
///
/// Deliberately **not** `Recency`. Everything else Chalk orders — tiles, gyms, machines —
/// is derived from entries and has nothing to maintain (SPEC §7.1, §7.4). Groups are the
/// exception, and have to be: a shelf you arranged that reshuffled itself as you lifted
/// would not be a shelf you arranged.
enum GroupOrder {

    /// Groups in the user's order. The name only settles a tie, so that two groups
    /// sharing an index still draw in a stable order rather than in a fetch's.
    ///
    /// Ties are possible even though `move(fromOffsets:toOffset:)` renumbers densely:
    /// `create` appends past the current maximum without renumbering, and a store
    /// arriving from another device later need not be dense at all.
    static func inOrder(_ groups: [ExerciseGroup]) -> [ExerciseGroup] {
        groups.sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
    }
}
