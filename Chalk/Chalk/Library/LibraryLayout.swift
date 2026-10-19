import Foundation

/// One exercise in the grid, with what you last did for it already read off the store
/// (SPEC §7.1). The tile view is handed this rather than an `Exercise`, so nothing
/// behind `var body` faults an entries relationship back in.
struct LibraryTile: Identifiable {
    let exercise: Exercise
    /// A lift's last entry; `nil` for an exercise with nothing logged, and on every erg.
    let lastEntry: LastEntry?
    /// An erg's last valid interval; `nil` for an erg with nothing logged, and on every
    /// lift.
    let lastInterval: LastInterval?
    /// Where this tile is filed, `nil` for Ungrouped. Read here with everything else so
    /// Arrange mode's group picker can tick the current group without faulting the
    /// relationship back in behind `var body`.
    let groupID: UUID?

    var id: UUID { exercise.id }
    var name: String { exercise.name }

    init(exercise: Exercise, lastEntry: LastEntry?, lastInterval: LastInterval? = nil) {
        self.exercise = exercise
        self.lastEntry = lastEntry
        self.lastInterval = lastInterval
        self.groupID = exercise.group?.id
    }

    /// The tile for `exercise`, with its last entry read off the store: a lift's for a
    /// lift, a valid interval's for an erg.
    init(exercise: Exercise) {
        let entries = exercise.entries ?? []
        self.init(
            exercise: exercise,
            lastEntry: exercise.isErg ? nil : LastEntry.latest(in: entries),
            lastInterval: exercise.isErg ? LastInterval.latest(in: entries) : nil
        )
    }

    /// When you last did it — what the tile's recency is read by.
    var lastDate: Date? { lastEntry?.date ?? lastInterval?.date }

    /// The line under the name: `8 × 52.5 kg · today`, or `6:00 at 15.0 km/h · today` —
    /// an erg's without its heart rates (SPEC §13.5). `nil` with nothing logged: that
    /// tile shows no subtitle at all.
    func subtitle(asOf now: Date = .now) -> String? {
        lastEntry?.text(asOf: now) ?? lastInterval?.tileText(asOf: now)
    }
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

    /// This section as a drop target, so the highlight can be compared without the
    /// double-optional an `Identifiable` with an optional id would otherwise force on
    /// the view holding it.
    var dropTarget: LibraryDropTarget { id.map(LibraryDropTarget.group) ?? .ungrouped }
}

/// Where a dragged tile can land: a section of the grid (SPEC §7.2).
///
/// A type of its own rather than the section's title, because two groups may share a
/// name — this is a shelf, not a classification — and a highlight that lit both would be
/// a lie about where the tile is going.
enum LibraryDropTarget: Hashable {
    case group(UUID)
    /// The bucket that ends the screen. Filing *out* of a group is as real a move as
    /// filing into one, so Ungrouped is a drop target like any other.
    case ungrouped
}

/// The last thing you logged, anywhere in the library — what the resume card at the top
/// of the screen shows (SPEC §7.1, §13.5). Absent when nothing has been logged at all.
struct LibraryResume {
    let exercise: Exercise
    /// The resumed lift, on strength's card.
    let lastEntry: LastEntry?
    /// The resumed interval, on endurance's card.
    let lastInterval: LastInterval?
    /// The goal at **the resumed entry's own scope** — that entry's machine for a
    /// gym-bound exercise, the exercise for a free-weight one — which the card draws as a
    /// ring with no words. Nil where that scope holds no goal: **a sibling machine's goal
    /// is never borrowed**, so a log at a holiday gym never shows your home machine's.
    let goal: Goal?
    /// Endurance's `goal`: the endurance goal at the resumed interval's own scope — that
    /// interval's machine for a gym-bound erg, the erg for a transferable one — under the
    /// same rule. Nil on strength's card.
    let enduranceGoal: EnduranceGoal?

    /// What the card's ring draws: how far from the goal's origin you have come, clamped
    /// to 0…1, and whether it is reached. The same for both halves.
    struct Ring: Equatable {
        let progress: Double
        let isReached: Bool
    }

    /// The card's ring, or nil where the resumed entry's scope holds no goal.
    var ring: Ring? {
        if let goal { return Ring(progress: goal.progress, isReached: goal.isReached) }
        if let enduranceGoal { return Ring(progress: enduranceGoal.progress, isReached: enduranceGoal.isReached) }
        return nil
    }

    init(exercise: Exercise, lastEntry: LastEntry, goal: Goal?) {
        self.exercise = exercise
        self.lastEntry = lastEntry
        self.lastInterval = nil
        self.goal = goal
        self.enduranceGoal = nil
    }

    /// An erg's card.
    init(exercise: Exercise, lastInterval: LastInterval, goal: EnduranceGoal?) {
        self.exercise = exercise
        self.lastEntry = nil
        self.lastInterval = lastInterval
        self.goal = nil
        self.enduranceGoal = goal
    }

    /// The card's line: `8 × 52.5 kg · today`, or an erg's last entry in the written form
    /// with its heart rates — `6:00 at 15.0 km/h (4:00 /km) · 1 % · 168/174 bpm · today`.
    func text(asOf now: Date = .now) -> String {
        lastEntry?.text(asOf: now) ?? lastInterval?.text(asOf: now) ?? ""
    }

    /// The card for `exercise`, or nil when it has nothing to resume. `zones` are the
    /// heart-rate zones, read live by the caller — an endurance goal is judged in them.
    init?(exercise: Exercise, zones: HeartRateZones? = nil) {
        if exercise.isErg {
            guard let entry = LastInterval.latestEntry(in: exercise.entries ?? []),
                  let lastInterval = LastInterval(entry)
            else { return nil }
            self.init(
                exercise: exercise,
                lastInterval: lastInterval,
                goal: GoalScope(exercise: exercise, machine: entry.machine)?.enduranceGoal(zones: zones)
            )
            return
        }
        guard let entry = LastEntry.latestEntry(in: exercise.entries ?? []),
              let lastEntry = LastEntry(entry)
        else { return nil }
        self.init(
            exercise: exercise,
            lastEntry: lastEntry,
            goal: GoalScope(exercise: exercise, machine: entry.machine)?.goal
        )
    }
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

    /// `zones` are the heart-rate zones, read live by the caller: the endurance card's
    /// ring is judged in them.
    init(exercises: [Exercise], groups: [ExerciseGroup], zones: HeartRateZones? = nil) {
        tiles = Self.byRecency(exercises)
        sections = Self.sections(tiles: tiles, groups: groups)
        // The tiles are in recency order, so the library's most recent entry is the
        // first tile's — if that tile has one at all. The entry is read again for its
        // machine, once, rather than carried on every tile: only the card needs a scope.
        resume = tiles.first.flatMap { LibraryResume(exercise: $0.exercise, zones: zones) }
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
            if let groupID = tile.groupID {
                filed[groupID, default: []].append(tile)
            } else {
                ungrouped.append(tile)
            }
        }

        // The user's arrangement, read through the one rule Edit groups rearranges —
        // `LibraryModel` already hands these over in order, and sorting again here keeps
        // the type honest for any caller that does not.
        var sections = GroupOrder.inOrder(groups)
            .compactMap { group -> LibrarySection? in
                guard let tiles = filed[group.id], !tiles.isEmpty else { return nil }
                return LibrarySection(id: group.id, title: group.name, tiles: tiles)
            }
        if !ungrouped.isEmpty {
            sections.append(LibrarySection(id: nil, title: ungroupedTitle, tiles: ungrouped))
        }
        return sections
    }

    /// Most recently logged first, never-logged after them, ties by name (SPEC §7.1) —
    /// `Recency`'s rule, over tiles.
    ///
    /// Each exercise's last entry is read into its tile **before** the sort rather than
    /// inside the comparator, which runs O(n log n) times and would fault the whole
    /// entries relationship back in on every call.
    ///
    /// Recency is the last *lift* — on an erg, the last *valid interval* — the same value
    /// the subtitle draws: a zeroed row is not something you did (SPEC §3), so it neither
    /// writes a subtitle nor floats a tile.
    private static func byRecency(_ exercises: [Exercise]) -> [LibraryTile] {
        Recency.order(
            exercises.map(LibraryTile.init(exercise:)),
            lastUsed: \.lastDate,
            name: \.name
        )
    }
}
