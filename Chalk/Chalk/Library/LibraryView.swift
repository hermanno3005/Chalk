import SwiftData
import SwiftUI

/// The exercise library — the app's home screen and the root of the `NavigationStack`
/// (SPEC §7.1). A sectioned tile grid with search pinned in thumb reach. An exercise is
/// filed into a group when it is created (SPEC §7.3), and **re-filed** here two ways
/// (§7.2): **dragging a tile into a section**, and **Arrange mode**, which puts a picker
/// on every tile.
struct LibraryView: View {
    let model: LibraryModel

    @State private var creating: CreateRequest?
    /// What is pushed on top of the library. A path of its own rather than
    /// `NavigationLink`-per-tile: a tile is a plain view so Arrange mode (#30) can drag
    /// it, and a link would claim the press exactly as a `Button` does (SPEC §7.2).
    @State private var opened: [Exercise] = []
    /// The exercise *Log again* has the log sheet open over, captured at the tap. Held
    /// rather than re-read from `model.resume` at presentation: the card moves the
    /// instant anything is logged, and a sheet in flight must not change the exercise
    /// under a half-typed weight.
    @State private var loggingAgain: LoggingRequest?
    /// The `New gym…` sheet, opened from the overflow's Gym menu — one of the three
    /// doors gyms are created behind (SPEC §7.4).
    @State private var creatingGym = false
    /// Arrange mode: every tile grows a group picker and a tap no longer navigates
    /// (SPEC §7.2). A mode, so it has a visible way out — see the toolbar.
    @State private var arranging = false
    @State private var editingGroups = false
    /// `Manage gyms…`, the one gym admin surface (SPEC §7.4) — a sheet from the same
    /// menu *Edit groups…* opens from, and the only door to it.
    @State private var managingGyms = false
    /// Settings, from *Settings…* at the overflow's foot (ADR-0005). Made at the tap, so
    /// it opens on the zones as they are now.
    @State private var settings: SettingsModel?
    /// Whether the search field is first responder — **the state that makes the keyboard
    /// dismissible at all** (#56). It lives here rather than in `LibrarySearchField`
    /// because every exit from the keyboard is a gesture on the library around the field,
    /// not a control on the field itself.
    @FocusState private var searchFocused: Bool
    /// The section a drag is currently over, for its highlight.
    ///
    /// **View state, deliberately not the model's** — SPEC §7.2's third hazard. This
    /// changes on every frame of a drag, and the ordering it would otherwise invalidate
    /// is cached in `LibraryModel` and refreshed on mutation, so a drag re-renders the
    /// grid without re-sorting a thing.
    @State private var dropTarget: LibraryDropTarget?

    var body: some View {
        NavigationStack(path: $opened) {
            keyboardDismissingContent
                .chalkScreen()
                .navigationDestination(for: Exercise.self) { exercise in
                    if exercise.isErg {
                        ErgDetailView(model: model.ergDetail(for: exercise))
                    } else {
                        ExerciseDetailView(model: model.detail(for: exercise))
                    }
                }
                // **Every route off this screen at once** — a result row, a grid tile
                // and the resume card all push onto this path, so ending the search
                // here covers the three of them rather than three call sites (#58).
                // On the way *out*, not the way back: the library stays alive under a
                // pushed screen, so its field keeps first responder — and the keyboard
                // rides along to a screen with no field under it — unless something
                // resigns it as the push begins. Dropping it here also means a swipe
                // back reveals the grid rather than a stale results list.
                .onChange(of: opened) { previous, current in
                    guard current.count > previous.count else { return }
                    searchFocused = false
                    model.endSearch()
                }
                // Never drawn — the switch stands in its place — but it is what a
                // pushed screen's back button says.
                .navigationTitle(model.half.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // **The switch stands where the "Chalk" title was** (SPEC §13.5), on
                    // this screen only, so switching always lands on that half's home.
                    ToolbarItem(placement: .principal) { halfSwitch }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(model.half == .endurance ? "New erg" : "New exercise", systemImage: "plus") {
                            creating = CreateRequest(name: "", half: model.half)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        // **Done replaces the overflow** rather than joining it: Arrange
                        // is a mode, so it gets a visible exit instead of making you go
                        // back through the menu you entered by — and the menu is not what
                        // you want mid-arrange anyway (SPEC §7.2).
                        if arranging {
                            Button("Done") {
                                withAnimation(.snappy) { arranging = false }
                            }
                            .fontWeight(.semibold)
                        } else {
                            overflow
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    LibrarySearchField(
                        query: Binding(
                            get: { model.query },
                            set: { typed in
                                // Typing is finding, not filing. Results are a plain list
                                // rather than tiles, so there are no pickers on them and a
                                // `Done` over them would be pointing at nothing — leaving
                                // the mode is the honest thing for a search to do.
                                if !typed.isEmpty { arranging = false }
                                model.search(typed)
                            }
                        ),
                        isFocused: $searchFocused,
                        prompt: model.half == .endurance ? "Search or add an erg" : "Search or add an exercise"
                    )
                }
                .sheet(item: $loggingAgain) { request in
                    // Exactly as the detail screen opens it (SPEC §6.4): a free-weight
                    // exercise needs nothing else from its caller. An erg's card opens
                    // the lap-list grid instead (SPEC §13.7).
                    if let lapList = model.lapList(for: request.exercise) {
                        LapListSheet(model: lapList)
                    } else {
                        LogSheet(model: model.logSheet(for: request.exercise))
                    }
                }
                .sheet(item: $creating) { request in
                    if request.half == .endurance {
                        // Creating leaves you on the grid with the new tile on it, as a
                        // lift does — no machine yet: the first log resolves it (§13.6).
                        CreateErgSheet(seedName: request.name, groups: model.groups) { draft in
                            model.create(draft)
                        }
                    } else {
                        createExerciseSheet(request)
                    }
                }
                .sheet(isPresented: $editingGroups) {
                    // The grid behind it moves as you edit: `GroupsModel` is wired to
                    // the library's refresh, so a rename or a reorder has already landed
                    // by the time the sheet is dismissed.
                    EditGroupsSheet(groups: model.groups)
                }
                .sheet(isPresented: $managingGyms) {
                    // Every verb on it writes through `GymsModel`, which the create
                    // sheet, the log sheet and the detail screen all read, so the app
                    // behind the sheet is already in step when it closes.
                    ManageGymsSheet(gyms: model.gyms)
                }
                // A relabel or a convert there moves the scale every tile and the resume card write in.
                .sheet(item: $settings, onDismiss: model.refresh) { settings in
                    SettingsSheet(model: settings)
                }
                .sheet(isPresented: $creatingGym) {
                    // Created here and selected here: you opened this door standing in
                    // the gym, so that is where you now are.
                    NewGymSheet(gyms: model.gyms) { model.gyms.select($0) }
                }
        }
    }

    /// The `Strength | Endurance` control (SPEC §13.5). Leaving a half leaves its modes
    /// too: Arrange and a half-typed search belong to the half they were started on.
    private var halfSwitch: some View {
        Picker("Half", selection: Binding(
            get: { model.half },
            set: { half in
                arranging = false
                searchFocused = false
                model.show(half)
            }
        )) {
            ForEach(Half.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
    }

    private func createExerciseSheet(_ request: CreateRequest) -> some View {
        CreateExerciseSheet(
            seedName: request.name,
            gyms: model.gyms,
            groups: model.groups
        ) { name, kind, group, gym, manufacturer in
            // Creating leaves you on the grid with the new tile on it — under the group
            // that was picked (§7.3) — and the detail screen is a tap away with nothing
            // on it yet.
            model.create(
                name: name,
                kind: kind,
                group: group,
                gym: gym,
                manufacturer: manufacturer
            )
        }
    }

    /// The overflow. *Arrange* and *Edit groups…* are the two halves of §7.2 — one files
    /// exercises into groups, the other edits the groups themselves. The foot is the part
    /// every half shares: the Gym menu, carrying §7.4's symmetric pair, and *Settings…*.
    private var overflow: some View {
        Menu {
            Section {
                Button("Arrange", systemImage: "square.grid.2x2") {
                    withAnimation(.snappy) { arranging = true }
                }
                Button("Edit groups…", systemImage: "folder") { editingGroups = true }
            }
            SharedOverflow(
                gyms: model.gyms,
                onNewGym: { creatingGym = true },
                onManageGyms: { managingGyms = true },
                onSettings: { settings = model.settings() }
            )
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    /// The library, over **the two surfaces that put the keyboard away**: a tap (#56) and
    /// a scroll (#57).
    ///
    /// A `simultaneousGesture` rather than `onTapGesture`, so it takes taps from nothing:
    /// the tiles, the result rows, the Arrange-mode pickers and the resume card all still
    /// see the same tap, and a `TapGesture` fails the moment a finger moves, so a tile is
    /// still a drag source. `contentShape` is what makes the empty regions tappable —
    /// without it the two states with nothing drawn in them, a first-launch library and a
    /// query that matched nothing, would have no exit at all, and they are precisely the
    /// states no scroll can reach, which is why the tap is the exit that has to work.
    ///
    /// `.interactively` is a change of manner rather than of fact: a scroll already
    /// dismissed the keyboard by default, but it vanished the instant the drag began.
    /// Now it tracks the finger and is left wherever the finger lets go, which is how
    /// the rest of the platform behaves. Set here rather than on each scroll view
    /// because it travels through the environment, so the grid and the results list
    /// both take it from one place — the same place their other keyboard exit lives.
    private var keyboardDismissingContent: some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { searchFocused = false })
    }

    @ViewBuilder
    private var content: some View {
        switch model.content {
        case .empty:
            EmptyLibraryView(half: model.half) { creating = CreateRequest(name: "", half: model.half) }
        case .grid(let sections):
            grid(sections)
        case .searching(let matches, let createSuggestion):
            results(matches, createSuggestion: createSuggestion)
        }
    }

    // MARK: - The grid

    private func grid(_ sections: [LibrarySection]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // The single likeliest thing you want, above everything (SPEC §7.1).
                // Absent altogether when nothing has been logged — and while arranging,
                // because it is the one thing on this screen that is not a tile you can
                // file, and it holds the biggest target on it.
                if let resume = model.resume, !arranging {
                    ResumeCard(
                        resume: resume,
                        onOpen: { opened.append(resume.exercise) },
                        onLogAgain: { loggingAgain = LoggingRequest(exercise: resume.exercise) }
                    )
                }
                ForEach(sections) { section in
                    self.section(section)
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    /// One section of the grid, and **one drop target** (SPEC §7.2). The whole section
    /// takes the drop, header and tiles alike, because the header alone is a 20-point
    /// strip to land a finger on.
    ///
    /// A group holding nothing has no section, so it is not a drop target either — which
    /// is exactly why the drag is never the path that has to work. The picker offers
    /// every group, empty ones included.
    private func section(_ section: LibrarySection) -> some View {
        let isTarget = dropTarget == section.dropTarget
        return VStack(alignment: .leading, spacing: 8) {
            header(section)
            // A `Grid` rather than a `LazyVGrid`: a lone last tile spans both columns, so
            // no row leaves half the screen empty, and the tiles in a row share its height
            // when one's last entry takes a second line (SPEC §15.4).
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(section.rows, id: \.first?.id) { row in
                    GridRow {
                        ForEach(row) { tile in
                            ExerciseTile(
                                tile: tile,
                                arranging: arranging,
                                groups: model.groups.groups,
                                onOpen: { opened.append(tile.exercise) },
                                onAssign: { model.assign(tile.exercise, to: model.groups.group(id: $0)) }
                            )
                            .gridCellColumns(row.count == 1 ? LibrarySection.columns : 1)
                        }
                    }
                }
            }
        }
        .padding(isTarget ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.accentColor.opacity(isTarget ? 0.12 : 0))
        )
        .dropDestination(for: DraggedExercise.self) { dropped, _ in
            let group = model.groups.group(id: section.id)
            // An id the library no longer holds — a tile deleted on the way down — files
            // nothing, and the drop says so rather than swallowing it.
            return dropped.reduce(false) { filed, dragged in
                model.assign(exerciseWithID: dragged.id, to: group) || filed
            }
        } isTargeted: { over in
            // Cleared only by the section that owns it: `isTargeted` fires `false` for
            // the section being left *after* `true` for the one being entered, and
            // clearing unconditionally would drop the new highlight on the floor.
            if over {
                dropTarget = section.dropTarget
            } else if dropTarget == section.dropTarget {
                dropTarget = nil
            }
        }
    }

    private func header(_ section: LibrarySection) -> some View {
        HStack(spacing: 6) {
            Text(section.title)
                .font(.footnote.weight(.semibold))
            Spacer()
            Text("\(section.tiles.count)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        // Ungrouped is a bucket rather than a group of your own, and reads as one.
        .foregroundStyle(section.isUngrouped ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
    }

    // MARK: - Searching

    /// Results as a plain list, with **Create it** as the last row when the typed name
    /// matched nothing — find and create are the same gesture (SPEC §7.1).
    private func results(_ matches: [LibraryTile], createSuggestion: String?) -> some View {
        List {
            ForEach(matches) { tile in
                Button {
                    opened.append(tile.exercise)
                } label: {
                    Text(tile.name)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .chalkRows()
            if let createSuggestion {
                Button {
                    creating = CreateRequest(name: createSuggestion, half: model.half)
                } label: {
                    Label("Create “\(createSuggestion)”", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                }
                .chalkRows()
            }
        }
        .listStyle(.plain)
    }
}

/// A log sheet in flight, carrying the exercise it was opened over — the resume card's
/// at the moment *Log again* was tapped, whatever the card says by the time it closes.
private struct LoggingRequest: Identifiable {
    let id = UUID()
    let exercise: Exercise
}

/// A create sheet in flight, carrying the name the search field already holds. An
/// identified value rather than a `Bool`, so the sheet is built with the seed rather
/// than reading it after the fact.
private struct CreateRequest: Identifiable {
    let id = UUID()
    let name: String
    /// The half it was opened on, which decides the sheet: an exercise or an erg. Held
    /// rather than read at presentation, as the name is.
    let half: Half
}

private extension Half {
    /// The half's name, on the switch and on a pushed screen's back button.
    var title: String {
        switch self {
        case .strength: "Strength"
        case .endurance: "Endurance"
        }
    }
}

#Preview("Empty") {
    LibraryPreview.view(exercises: [])
}

#Preview("Grid") {
    LibraryPreview.view(exercises: [
        ("Squat", "Compound"), ("Bench Press", "Compound"),
        ("Leg Curl", "Legs"), ("Ab Wheel", nil),
    ])
}

/// An in-memory library, so the previews above are the real screen over the real model.
private enum LibraryPreview {
    @MainActor
    static func view(exercises: [(String, String?)]) -> some View {
        guard
            let container = try? ModelContainer(
                for: Schema(versionedSchema: ChalkSchemaV1.self),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ),
            // A suite of its own, so a preview never writes the seed flag into the
            // defaults a running app reads.
            let defaults = UserDefaults(suiteName: "chalk-preview-\(UUID().uuidString)")
        else {
            return AnyView(Text("No preview store."))
        }
        let context = ModelContext(container)
        SuggestedGroups.seedIfNeeded(in: context, defaults: defaults)
        let groups = (try? context.fetch(FetchDescriptor<ExerciseGroup>())) ?? []
        for (index, (name, group)) in exercises.enumerated() {
            let exercise = Exercise(name: name, group: groups.first { $0.name == group })
            context.insert(exercise)
            // Every exercise but the last carries an entry, so the preview shows the
            // resume card, the subtitles and a tile with none of either.
            if index < exercises.count - 1 {
                context.insert(Entry(
                    reps: 8,
                    weight: 52.5,
                    date: .now.addingTimeInterval(-86_400 * Double(index)),
                    exercise: exercise
                ))
            }
        }
        return AnyView(
            LibraryView(model: LibraryModel(context: context, defaults: defaults))
                .modelContainer(container)
        )
    }
}
