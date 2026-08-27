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
        case searching(matches: [LibraryTile], createSuggestion: String?)
    }

    private(set) var content: Content = .empty

    /// The last thing you logged, anywhere in the library — the card at the top of the
    /// grid (SPEC §7.1). `nil` when nothing has been logged, which is the whole of "an
    /// empty store has no resume card": there is no card state to draw, not an empty one.
    private(set) var resume: LibraryResume?

    /// What is in the search field. Set through `search(_:)` so the filtering happens
    /// once per keystroke rather than once per render.
    private(set) var query = ""

    /// The gyms, and the gym you are standing in (SPEC §7.4). Held here because the
    /// library's overflow is where the current gym is chosen, and because the create
    /// sheet's gym-bound branch and the detail screen's opening cascade both read it.
    let gyms: GymsModel

    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.gyms = GymsModel(context: context, defaults: defaults)
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
    /// `gym` and `make` are the **gym-bound branch's** answers and are ignored for a
    /// free-weight exercise, which has no machine to make. Given a gym, the first machine
    /// is created here so the exercise opens scoped to something you can log on; without
    /// one the exercise is simply machine-less until the first log makes one (§6.4).
    ///
    /// Returns `nil` for a name that is blank once trimmed. Nothing else can fail: an
    /// exercise with the same name as another is allowed, because two racks really can
    /// carry the same label.
    @discardableResult
    func create(
        name: String,
        kind: ExerciseKind,
        gym: Gym? = nil,
        make: String? = nil
    ) -> Exercise? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let exercise = Exercise(name: name, kind: kind)
        context.insert(exercise)

        if kind == .gymBound, let gym {
            let make = make?.trimmingCharacters(in: .whitespacesAndNewlines)
            context.insert(Machine(
                manufacturer: (make?.isEmpty == false) ? make : nil,
                exercise: exercise,
                gym: gym
            ))
        }
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
        ExerciseDetailModel(exercise: exercise, context: context, gyms: gyms) { [weak self] in
            self?.refresh()
        }
    }

    /// The log sheet over `exercise`, wired to put the card and the tiles back in step
    /// when it writes (SPEC §6.7). This is what **Log again** opens, and it seeds itself
    /// from that exercise's most recent entry — the one the card is showing.
    ///
    /// **The machine comes from the entry being resumed** (SPEC §6.4) — the card is
    /// showing one lift, and *Log again* means again on that machine. The current gym is
    /// not consulted: it is upstream of the detail screen and never enters the sheet.
    func logSheet(for exercise: Exercise, onSave: @escaping () -> Void = {}) -> LogSheetModel {
        LogSheetModel(
            exercise: exercise,
            machine: resumedMachine(for: exercise),
            context: context
        ) { [weak self] in
            self?.refresh()
            onSave()
        }
    }

    /// The machine of the exercise's most recent lift — the one the resume card is
    /// showing, read the same way `LastEntry` reads the words on it.
    private func resumedMachine(for exercise: Exercise) -> Machine? {
        (exercise.entries ?? [])
            .filter(\.isALift)
            .max { $0.date < $1.date }?
            .machine
    }

    /// Re-reads the store and rebuilds the cached ordering. Called after every mutation
    /// this model makes, and by anything that changes the library behind its back.
    func refresh() {
        // Gym order is derived from entries, so anything logged anywhere can move it.
        gyms.refresh()
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let groups = (try? context.fetch(FetchDescriptor<ExerciseGroup>())) ?? []
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let layout = LibraryLayout(exercises: exercises, groups: groups)
        resume = layout.resume

        if typed.isEmpty {
            content = layout.sections.isEmpty ? .empty : .grid(layout.sections)
        } else {
            let matches = layout.matches(query: typed)
            content = .searching(
                matches: matches,
                createSuggestion: matches.isEmpty ? typed : nil
            )
        }
    }
}
