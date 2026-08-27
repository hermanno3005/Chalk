import Foundation

/// One exercise in the grid, with what you last did for it already read off the store
/// (SPEC §7.1). The tile view is handed this rather than an `Exercise`, so nothing
/// behind `var body` faults an entries relationship back in.
struct LibraryTile: Identifiable {
    let exercise: Exercise
    /// `nil` for an exercise with nothing logged — that tile shows no subtitle at all.
    let lastEntry: LastEntry?

    var id: UUID { exercise.id }
    var name: String { exercise.name }
}

/// One section of the library grid: a group and the exercises filed under it, or the
/// Ungrouped bucket that ends the screen (SPEC §7.1).
struct LibrarySection: Identifiable {
    /// The group's id. `nil` is Ungrouped, which is where an exercise sits when it is
    /// in no group at all — a bucket, not a group of its own.
    let id: UUID?
    let title: String
    let tiles: [LibraryTile]

    var isUngrouped: Bool { id == nil }
}

/// The last thing you logged, anywhere in the library — what the resume card at the top
/// of the screen shows (SPEC §7.1). Absent when nothing has been logged at all.
struct LibraryResume {
    let exercise: Exercise
    let lastEntry: LastEntry
}

/// Everything the library screen draws, derived in **one** pass over models already
/// fetched: the resume card, the sections, and the tiles search filters. One pass rather
/// than three because every one of them needs the same thing — each exercise's most
/// recent entry — and reading that is the expensive half.
///
/// Deliberately a value built on mutation, not computed properties on a view (SPEC §7.2,
/// hazard 3): the drop-target highlight is observable state, so a sort behind `var body`
/// re-ran a full sort once per group per frame of a drag. `LibraryModel` builds one of
/// these per mutation and caches it.
struct LibraryLayout {

    /// Every exercise in recency order — what search filters, and where the sections and
    /// the resume card both come from.
    let tiles: [LibraryTile]
    let sections: [LibrarySection]
    let resume: LibraryResume?

    /// The last section's title. Not a group name — no `ExerciseGroup` is ever called this.
    static let ungroupedTitle = "Ungrouped"

    init(exercises: [Exercise], groups: [ExerciseGroup]) {
        tiles = Self.byRecency(exercises)
        sections = Self.sections(tiles: tiles, groups: groups)
        // The tiles are in recency order, so the library's most recent entry is the
        // first tile's — if that tile has one at all.
        resume = tiles.first.flatMap { tile in
            tile.lastEntry.map { LibraryResume(exercise: tile.exercise, lastEntry: $0) }
        }
    }

    /// The tiles whose name contains `query`, ignoring case and diacritics, in the same
    /// order the grid would draw them. A query that is blank once trimmed matches
    /// everything — it is a field someone has not typed into yet, not a filter.
    func matches(query: String) -> [LibraryTile] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tiles }
        return tiles.filter {
            $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// Sections in the user's own order (`sortIndex`), Ungrouped last.
    ///
    /// A group holding nothing is left out: the grid is the pile made legible, and an
    /// empty header makes it less so. Groups stay reachable while empty through the
    /// group picker, which is where filing happens.
    ///
    /// `tiles` arrives in recency order and every bucket keeps it, so within-group
    /// ordering is recency without a second sort.
    private static func sections(
        tiles: [LibraryTile],
        groups: [ExerciseGroup]
    ) -> [LibrarySection] {
        var filed: [UUID: [LibraryTile]] = [:]
        var ungrouped: [LibraryTile] = []
        for tile in tiles {
            if let groupID = tile.exercise.group?.id {
                filed[groupID, default: []].append(tile)
            } else {
                ungrouped.append(tile)
            }
        }

        // `sortIndex` is the user's arrangement; the name only settles a tie, so that two
        // groups sharing an index still draw in a stable order rather than a fetch's.
        var sections = groups
            .sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
            .compactMap { group -> LibrarySection? in
                guard let tiles = filed[group.id], !tiles.isEmpty else { return nil }
                return LibrarySection(id: group.id, title: group.name, tiles: tiles)
            }
        if !ungrouped.isEmpty {
            sections.append(LibrarySection(id: nil, title: ungroupedTitle, tiles: ungrouped))
        }
        return sections
    }

    /// Most recently logged first, never-logged after them, ties by name (SPEC §7.1).
    ///
    /// Each exercise's last entry is read **once**, before the sort, rather than inside
    /// the comparator: the comparator runs O(n log n) times and every call would fault
    /// the whole entries relationship back in.
    ///
    /// Recency is the last *lift*, the same value the subtitle draws: a zeroed row is not
    /// something you did (SPEC §3), so it neither writes a subtitle nor floats a tile.
    private static func byRecency(_ exercises: [Exercise]) -> [LibraryTile] {
        exercises
            .map { LibraryTile(exercise: $0, lastEntry: LastEntry.latest(in: $0.entries ?? [])) }
            .sorted { left, right in
                switch (left.lastEntry?.date, right.lastEntry?.date) {
                case let (leftDate?, rightDate?) where leftDate != rightDate:
                    leftDate > rightDate
                case (nil, _?):
                    false
                case (_?, nil):
                    true
                default:
                    left.name.localizedStandardCompare(right.name) == .orderedAscending
                }
            }
    }
}
