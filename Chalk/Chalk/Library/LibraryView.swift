import SwiftData
import SwiftUI

/// The exercise library — the app's home screen and the root of the `NavigationStack`
/// (SPEC §7.1). A sectioned tile grid with search pinned in thumb reach.
///
/// The resume card and the tiles' `8 × 52.5 kg · today` subtitles need entries and land
/// with #25; Arrange mode and Edit groups with #30.
struct LibraryView: View {
    let model: LibraryModel
    /// Opening an exercise. The detail screen arrives with #23; the tap is wired now so
    /// the tile stays a plain view when it does.
    var onOpen: (Exercise) -> Void = { _ in }

    @State private var creating: CreateRequest?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Chalk")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New exercise", systemImage: "plus") {
                            creating = CreateRequest(name: "")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    LibrarySearchField(query: Binding(
                        get: { model.query },
                        set: { model.search($0) }
                    ))
                }
                .sheet(item: $creating) { request in
                    CreateExerciseSheet(seedName: request.name) { name, kind in
                        // Creating leaves you on the grid with the new tile on it — the
                        // detail screen is a tap away and has nothing on it yet.
                        model.create(name: name, kind: kind)
                    }
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
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        header(section)
                        LazyVGrid(columns: Self.tileColumns, spacing: 10) {
                            ForEach(section.exercises) { exercise in
                                ExerciseTile(exercise: exercise) { onOpen(exercise) }
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
            Text("\(section.exercises.count)")
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
    private func results(_ matches: [Exercise], createSuggestion: String?) -> some View {
        List {
            ForEach(matches) { exercise in
                Button {
                    onOpen(exercise)
                } label: {
                    Text(exercise.name)
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

/// A create sheet in flight, carrying the name the search field already holds. An
/// identified value rather than a `Bool`, so the sheet is built with the seed rather
/// than reading it after the fact.
private struct CreateRequest: Identifiable {
    let id = UUID()
    let name: String
}

/// First launch: **real copy saying what the app is for, and a way in. Not a wordmark**
/// (SPEC §7.1).
struct EmptyLibraryView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Keep the lifts you actually do")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Log what you lifted as plain reps × weight. Chalk works out what you have proven at every rep count, and what to load next time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button(action: onCreate) {
                Text("Add your first exercise")
                    .frame(maxWidth: 260)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
        let container = try! ModelContainer(
            for: Schema(versionedSchema: ChalkSchemaV1.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let defaults = UserDefaults(suiteName: "chalk-preview-\(UUID().uuidString)")!
        SuggestedGroups.seedIfNeeded(in: context, defaults: defaults)
        let groups = (try? context.fetch(FetchDescriptor<ExerciseGroup>())) ?? []
        for (name, group) in exercises {
            context.insert(Exercise(name: name, group: groups.first { $0.name == group }))
        }
        return LibraryView(model: LibraryModel(context: context, defaults: defaults))
            .modelContainer(container)
    }
}
