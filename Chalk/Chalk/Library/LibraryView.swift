import SwiftData
import SwiftUI

/// The exercise library — the app's home screen and the root of the `NavigationStack`
/// (SPEC §7.1). A sectioned tile grid with search pinned in thumb reach, and the two
/// ways an exercise is filed into a group (SPEC §7.2): **dragging a tile into a section**,
/// and **Arrange mode**, which puts a picker on every tile.
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
    /// The section a drag is currently over, for its highlight.
    ///
    /// **View state, deliberately not the model's** — SPEC §7.2's third hazard. This
    /// changes on every frame of a drag, and the ordering it would otherwise invalidate
    /// is cached in `LibraryModel` and refreshed on mutation, so a drag re-renders the
    /// grid without re-sorting a thing.
    @State private var dropTarget: LibraryDropTarget?

    var body: some View {
        NavigationStack(path: $opened) {
            content
                .navigationDestination(for: Exercise.self) { exercise in
                    ExerciseDetailView(model: model.detail(for: exercise))
                }
                .navigationTitle("Chalk")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New exercise", systemImage: "plus") {
                            creating = CreateRequest(name: "")
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
                    LibrarySearchField(query: Binding(
                        get: { model.query },
                        set: { typed in
                            // Typing is finding, not filing. Results are a plain list
                            // rather than tiles, so there are no pickers on them and a
                            // `Done` over them would be pointing at nothing — leaving
                            // the mode is the honest thing for a search to do.
                            if !typed.isEmpty { arranging = false }
                            model.search(typed)
                        }
                    ))
                }
                .sheet(item: $loggingAgain) { request in
                    // Exactly as the detail screen opens it (SPEC §6.4): a free-weight
                    // exercise needs nothing else from its caller.
                    LogSheet(model: model.logSheet(for: request.exercise))
                }
                .sheet(item: $creating) { request in
                    CreateExerciseSheet(
                        seedName: request.name,
                        gyms: model.gyms,
                        groups: model.groups
                    ) { name, kind, group, gym, manufacturer in
                        // Creating leaves you on the grid with the new tile on it — under
                        // the group that was picked (§7.3) — and the detail screen is a
                        // tap away with nothing on it yet.
                        model.create(
                            name: name,
                            kind: kind,
                            group: group,
                            gym: gym,
                            manufacturer: manufacturer
                        )
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
                .sheet(isPresented: $creatingGym) {
                    // Created here and selected here: you opened this door standing in
                    // the gym, so that is where you now are.
                    NewGymSheet(gyms: model.gyms) { model.gyms.select($0) }
                }
        }
    }

    /// The overflow. *Arrange* and *Edit groups…* are the two halves of §7.2 — one files
    /// exercises into groups, the other edits the groups themselves — and the Gym menu
    /// carries §7.4's symmetric pair.
    private var overflow: some View {
        Menu {
            Section {
                Button("Arrange", systemImage: "square.grid.2x2") {
                    withAnimation(.snappy) { arranging = true }
                }
                Button("Edit groups…", systemImage: "folder") { editingGroups = true }
            }
            // The current-gym picker. *Manage gyms…* joins it at the foot of this menu,
            // a direct sibling of *Edit groups* (§7.4, #31).
            GymMenu(gyms: model.gyms, onNewGym: { creatingGym = true }, onManageGyms: { managingGyms = true })
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.content {
        case .empty:
            EmptyLibraryView { creating = CreateRequest(name: "") }
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
            LazyVGrid(columns: Self.tileColumns, spacing: 10) {
                ForEach(section.tiles) { tile in
                    ExerciseTile(
                        tile: tile,
                        arranging: arranging,
                        groups: model.groups.groups,
                        onOpen: { opened.append(tile.exercise) },
                        onAssign: { model.assign(tile.exercise, to: model.groups.group(id: $0)) }
                    )
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

    private static let tileColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

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
            if let createSuggestion {
                Button {
                    creating = CreateRequest(name: createSuggestion)
                } label: {
                    Label("Create “\(createSuggestion)”", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                }
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
