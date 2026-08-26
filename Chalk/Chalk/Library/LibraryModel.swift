import Foundation
import Observation
import SwiftData

/// The library screen's state, and the one mutation it owns (SPEC §7.1–7.3).
///
/// The ordering is **cached here and refreshed on mutation**, never computed behind
/// `var body` — SPEC §7.2's third hazard, which cost the prototype a round: the
/// drop-target highlight is observable state, so a sort in a computed property re-ran
/// once per group per frame of a drag.
@Observable
final class LibraryModel {

    /// Every state the library can be in, so none is invented at the keyboard (SPEC §9).
    enum Content {
        /// First launch: real copy and a way in, not a wordmark.
        case empty
        /// The sectioned tile grid.
        case grid([LibrarySection])
        /// Filtering as you type. `createSuggestion` is the typed name when nothing
        /// matched it — find and create are the same gesture (SPEC §7.1).
        case searching(matches: [Exercise], createSuggestion: String?)
    }

    private(set) var content: Content = .empty

    /// What is in the search field. Set through `search(_:)` so the filtering happens
    /// once per keystroke rather than once per render.
    private(set) var query = ""

    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        SuggestedGroups.seedIfNeeded(in: context, defaults: defaults)
        refresh()
    }

    /// Filters the library to `text`, or returns to the grid when it is cleared.
    func search(_ text: String) {
        query = text
        refresh()
    }

    /// Creates a free-weight or gym-bound exercise in **Ungrouped** — no group is asked
    /// for at create time, and no increment (SPEC §7.3) — and returns to the grid.
    ///
    /// Returns `nil` for a name that is blank once trimmed. Nothing else can fail: an
    /// exercise with the same name as another is allowed, because two racks really can
    /// carry the same label.
    @discardableResult
    func create(name: String, kind: ExerciseKind) -> Exercise? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let exercise = Exercise(name: name, kind: kind)
        context.insert(exercise)
        // v1 has no error state past §3's container failure, and there is no network, so
        // there is nothing here to report and nothing to retry: the insert stays in the
        // context either way and the next save takes it with it.
        try? context.save()

        // Creating from a search that found nothing returns you to the grid, with the
        // thing you just made in it.
        query = ""
        refresh()
        return exercise
    }

    /// The detail screen's state for one exercise (SPEC §5), made here so the store's
    /// context stays this model's own and so a rename or a delete over there puts the
    /// grid behind it back in step.
    ///
    /// A plain factory, not a cache: the pushed screen holds the first one it is given
    /// in `@State` and drops the rest, which costs one derivation pass per rebuild of
    /// the destination and keeps no model alive behind a screen that has been popped.
    func detail(for exercise: Exercise) -> ExerciseDetailModel {
        ExerciseDetailModel(exercise: exercise, context: context) { [weak self] in
            self?.refresh()
        }
    }

    /// Re-reads the store and rebuilds the cached ordering. Called after every mutation
    /// this model makes, and by anything that changes the library behind its back.
    func refresh() {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let groups = (try? context.fetch(FetchDescriptor<ExerciseGroup>())) ?? []
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if typed.isEmpty {
            content = exercises.isEmpty
                ? .empty
                : .grid(LibraryOrdering.sections(exercises: exercises, groups: groups))
        } else {
            let matches = LibraryOrdering.matches(exercises, query: typed)
            content = .searching(
                matches: matches,
                createSuggestion: matches.isEmpty ? typed : nil
            )
        }
    }
}
