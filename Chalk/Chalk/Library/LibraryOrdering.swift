import Foundation

/// One section of the library grid: a group and the exercises filed under it, or the
/// Ungrouped bucket that ends the screen (SPEC §7.1).
struct LibrarySection: Identifiable {
    /// The group's id. `nil` is Ungrouped, which is where an exercise sits when it is
    /// in no group at all — a bucket, not a group of its own.
    let id: UUID?
    let title: String
    let exercises: [Exercise]

    var isUngrouped: Bool { id == nil }
}

/// The library's ordering and its search, as plain functions over models already fetched.
///
/// Deliberately not computed properties on a view (SPEC §7.2, hazard 3): the drop-target
/// highlight is observable state, so a sort behind `var body` re-ran a full sort once per
/// group per frame of a drag. `LibraryModel` calls these once per mutation and caches
/// what comes back.
enum LibraryOrdering {

    /// The last section's title. Not a group name — no `ExerciseGroup` is ever called this.
    static let ungroupedTitle = "Ungrouped"

    /// Sections in the user's own order (`sortIndex`), Ungrouped last.
    ///
    /// A group holding nothing is left out: the grid is the pile made legible, and an
    /// empty header makes it less so. Groups stay reachable while empty through the
    /// group picker, which is where filing happens.
    static func sections(exercises: [Exercise], groups: [ExerciseGroup]) -> [LibrarySection] {
        var filed: [UUID: [Exercise]] = [:]
        var ungrouped: [Exercise] = []
        for exercise in exercises {
            if let groupID = exercise.group?.id {
                filed[groupID, default: []].append(exercise)
            } else {
                ungrouped.append(exercise)
            }
        }

        // `sortIndex` is the user's arrangement; the name only settles a tie, so that two
        // groups sharing an index still draw in a stable order rather than a fetch's.
        var sections = groups
            .sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
            .compactMap { group -> LibrarySection? in
                guard let exercises = filed[group.id], !exercises.isEmpty else { return nil }
                return LibrarySection(
                    id: group.id,
                    title: group.name,
                    exercises: byRecency(exercises)
                )
            }
        if !ungrouped.isEmpty {
            sections.append(LibrarySection(
                id: nil,
                title: ungroupedTitle,
                exercises: byRecency(ungrouped)
            ))
        }
        return sections
    }

    /// The exercises whose name contains `query`, ignoring case and diacritics, in the
    /// same order the grid would draw them. A query that is blank once trimmed matches
    /// everything — it is a field someone has not typed into yet, not a filter.
    static func matches(_ exercises: [Exercise], query: String) -> [Exercise] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return byRecency(exercises) }
        return byRecency(exercises.filter {
            $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        })
    }

    /// Most recently logged first, never-logged after them, ties by name (SPEC §7.1).
    ///
    /// Each exercise's last entry is read **once**, before the sort, rather than inside
    /// the comparator: the comparator runs O(n log n) times and every call would fault
    /// the whole entries relationship back in.
    private static func byRecency(_ exercises: [Exercise]) -> [Exercise] {
        exercises
            .map { (exercise: $0, lastLogged: $0.entries?.map(\.date).max()) }
            .sorted { left, right in
                switch (left.lastLogged, right.lastLogged) {
                case let (leftDate?, rightDate?) where leftDate != rightDate:
                    leftDate > rightDate
                case (nil, _?):
                    false
                case (_?, nil):
                    true
                default:
                    left.exercise.name.localizedStandardCompare(right.exercise.name)
                        == .orderedAscending
                }
            }
            .map(\.exercise)
    }
}
