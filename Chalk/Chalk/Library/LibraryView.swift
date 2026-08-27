import SwiftData
import SwiftUI

/// The exercise library — the app's home screen and the root of the `NavigationStack`
/// (SPEC §7.1). A sectioned tile grid with search pinned in thumb reach.
///
/// Arrange mode and Edit groups land with #30.
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
                        Menu {
                            // The current-gym picker. *Manage gyms…* joins it at the
                            // foot of this menu, a direct sibling of *Edit groups*
                            // (§7.4, #31).
                            GymMenu(gyms: model.gyms) { creatingGym = true }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    LibrarySearchField(query: Binding(
                        get: { model.query },
                        set: { model.search($0) }
                    ))
                }
                .sheet(item: $loggingAgain) { request in
                    // Exactly as the detail screen opens it (SPEC §6.4): a free-weight
                    // exercise needs nothing else from its caller.
                    LogSheet(model: model.logSheet(for: request.exercise))
                }
                .sheet(item: $creating) { request in
                    CreateExerciseSheet(seedName: request.name, gyms: model.gyms) { name, kind, gym, manufacturer in
                        // Creating leaves you on the grid with the new tile on it — the
                        // detail screen is a tap away and has nothing on it yet.
                        model.create(name: name, kind: kind, gym: gym, manufacturer: manufacturer)
                    }
                }
                .sheet(isPresented: $creatingGym) {
                    // Created here and selected here: you opened this door standing in
                    // the gym, so that is where you now are.
                    NewGymSheet(gyms: model.gyms) { model.gyms.select($0) }
                }
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
                // Absent altogether when nothing has been logged.
                if let resume = model.resume {
                    ResumeCard(
                        resume: resume,
                        onOpen: { opened.append(resume.exercise) },
                        onLogAgain: { loggingAgain = LoggingRequest(exercise: resume.exercise) }
                    )
                }
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        header(section)
                        LazyVGrid(columns: Self.tileColumns, spacing: 10) {
                            ForEach(section.tiles) { tile in
                                ExerciseTile(tile: tile) { opened.append(tile.exercise) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 24)
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
