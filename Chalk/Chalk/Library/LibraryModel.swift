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

    /// The groups, and Edit groups' four verbs (SPEC §7.2). Held here for the same
    /// reason the gyms are: the library's overflow is where they are edited, and the
    /// grid's sections and the tiles' group picker both read them.
    let groups: GroupsModel

    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.gyms = GymsModel(context: context, defaults: defaults)
        // Seeded before the groups are read, so first launch opens on the suggestion
        // rather than on an empty sheet.
        SuggestedGroups.seedIfNeeded(in: context, defaults: defaults)
        self.groups = GroupsModel(context: context)
        // Wired after `init`, not through it: a stored property cannot capture the
        // owner that is still initialising it.
        groups.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    /// Filters the library to `text`, or returns to the grid when it is cleared.
    func search(_ text: String) {
        query = text
        refresh()
    }

    /// Ends the search: clears the query and returns the screen to the grid.
    ///
    /// The closing half of the pair `search(_:)` opens — searching is not a mode and
    /// carries no Done, so its exits are clearing the field and **opening something**,
    /// and this is the second one (#58). Named rather than spelled `search("")` because
    /// the act is what the view calls and what a test can assert; an empty query is
    /// merely how it looks afterwards.
    ///
    /// Ending a search that was never started is a no-op, so the view can call it on
    /// every push rather than only the ones that leave a query behind.
    func endSearch() {
        guard !query.isEmpty else { return }
        query = ""
        refresh()
    }

    /// Creates a free-weight or gym-bound exercise **on the group the sheet picked**
    /// (SPEC §7.3, ADR-0003) — `nil` is **Ungrouped**, the picker's default and a free
    /// answer — and returns to the grid. No increment is asked for.
    ///
    /// `gym` and `manufacturer` are the **gym-bound branch's** answers — the sheet calls
    /// the second one *make*, which is what is written on the stack — and both are
    /// ignored for a free-weight exercise, which has no machine to make. Given a gym, the first machine
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
        group: ExerciseGroup? = nil,
        gym: Gym? = nil,
        manufacturer: String? = nil
    ) -> Exercise? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let exercise = Exercise(name: name, kind: kind, group: group)
        context.insert(exercise)

        if kind == .gymBound, let gym {
            let manufacturer = manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines)
            context.insert(Machine(
                manufacturer: (manufacturer?.isEmpty == false) ? manufacturer : nil,
                exercise: exercise,
                gym: gym
            ))
        }
        // v1 has no error state past §3's container failure, and there is no network, so
        // there is nothing here to report and nothing to retry: the insert stays in the
        // context either way and the next save takes it with it.
        try? context.save()

        // Creating from a search that found nothing returns you to the grid, with the
        // thing you just made in it — the third exit from a search. Spelled out rather
        // than `endSearch()` because the new exercise has to be picked up either way,
        // and going through it would cost a second `refresh` for the search case alone.
        query = ""
        refresh()
        return exercise
    }

    /// Files `exercise` under `group`, or under **Ungrouped** when that is `nil`.
    ///
    /// The one mutation behind both of SPEC §7.2's assignment paths — a tile dragged into a
    /// section, and the ••• group picker Arrange mode puts on every tile. **Re-filing, not
    /// first filing**: an exercise reaches its group at create time (§7.3, ADR-0003), and
    /// these two paths are the periodic re-shelving pass that corrects it afterwards.
    func assign(_ exercise: Exercise, to group: ExerciseGroup?) {
        exercise.group = group
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        refresh()
    }

    /// The same, for a **drop**, which carries an id rather than a model — a
    /// `PersistentModel` is not `Transferable` and must not cross a drag.
    ///
    /// Returns whether anything was filed. A drag can carry text from anywhere on the
    /// system, so an id this library does not hold is refused rather than guessed at, and
    /// the drop reports itself as not accepted.
    @discardableResult
    func assign(exerciseWithID id: UUID, to group: ExerciseGroup?) -> Bool {
        var descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let exercise = try? context.fetch(descriptor).first else { return false }

        assign(exercise, to: group)
        return true
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
            context: context,
            gyms: gyms
        ) { [weak self] in
            self?.refresh()
            onSave()
        }
    }

    /// The machine of the exercise's most recent lift — **the entry the resume card is
    /// showing**, found through the same definition of "what you last did" the card's
    /// words come from.
    private func resumedMachine(for exercise: Exercise) -> Machine? {
        LastEntry.latestEntry(in: exercise.entries ?? [])?.machine
    }

    /// Re-reads the store and rebuilds the cached ordering. Called after every mutation
    /// this model makes, and by anything that changes the library behind its back.
    func refresh() {
        // Gym order is derived from entries, so anything logged anywhere can move it.
        gyms.refresh()
        // The groups are re-read too: a rename, a reorder or a delete behind the grid
        // is a change to the sections it draws.
        groups.refresh()
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let layout = LibraryLayout(exercises: exercises, groups: groups.groups)
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
