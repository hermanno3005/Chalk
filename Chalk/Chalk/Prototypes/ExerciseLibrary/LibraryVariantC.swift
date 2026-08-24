// PROTOTYPE — throwaway.
//
// VARIANT C — Resume, then type. The screen opens on one big card: the last thing you
// logged, with a one-tap "Again" that repeats it outright. Below it, a search field
// pinned within thumb reach and a small grid of the exercises you have touched most
// recently. There is no browsable list at all — past the grid, you type.
//
// The argument: at 42 exercises no list is fast, but three letters always is. And the
// single most likely thing you want is another set of what you just did, so that gets
// the biggest target on the screen instead of a row in a list. Creating an exercise
// is the same gesture as finding one: type a name that does not exist and the last
// result is "Create it".
//
// The cost it accepts: you cannot browse. If you cannot remember what you called it,
// the screen has almost nothing to offer, and the grid only ever shows eight things.

import SwiftUI

struct LibraryVariantCResume: View {
    @Bindable var store: LibraryStore
    let onOpen: (ProtoExercise) -> Void
    let onLog: (ProtoExercise) -> Void

    @State private var query = ""
    @State private var creating = false
    @FocusState private var searchFocused: Bool

    private var results: [ProtoExercise] { store.matching(query) }
    private var grid: [ProtoExercise] { Array(store.byRecency.prefix(8)) }

    var body: some View {
        VStack(spacing: 0) {
            if store.exercises.isEmpty {
                emptyState
            } else if query.isEmpty {
                ScrollView {
                    VStack(spacing: 18) {
                        resumeCard
                        gridSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            } else {
                resultsList
            }
            searchBar
        }
        .navigationTitle("Chalk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("New exercise", systemImage: "plus") { creating = true }
                    Menu("Gym") {
                        ForEach(store.gyms, id: \.self) { gym in
                            Button(gym) { store.currentGym = gym }
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $creating) {
            CreateExerciseSheet(store: store, seedName: query) { created in
                query = ""
                onOpen(created)
            }
        }
    }

    // MARK: - Resume

    @ViewBuilder
    private var resumeCard: some View {
        if let exercise = store.lastLogged, let last = exercise.lastRecord {
            VStack(alignment: .leading, spacing: 12) {
                Text("LAST LOGGED · \(last.date.proAgo.uppercased())")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(exercise.name)
                    .font(.title2.weight(.semibold))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(last.reps)").font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("×").font(.title3).foregroundStyle(.secondary)
                    Text(last.weight.kg).font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("kg").font(.title3).foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Button { onLog(exercise) } label: {
                        Text("Log again").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Button { onOpen(exercise) } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .frame(width: 44)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(grid) { exercise in
                    Button { onOpen(exercise) } label: { tile(exercise) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Log a set", systemImage: "plus.circle") { onLog(exercise) }
                        }
                }
            }
            Text("\(store.exercises.count) exercises · search to reach the rest")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
    }

    private func tile(_ exercise: ProtoExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            Text(exercise.summary ?? "never logged")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Search

    private var resultsList: some View {
        List {
            ForEach(results) { exercise in
                Button { onOpen(exercise) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name).foregroundStyle(.primary)
                            Text(exercise.summary ?? "never logged")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Log") { onLog(exercise) }
                            .buttonStyle(.borderless)
                            .font(.subheadline.weight(.semibold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            // Find and create are the same gesture.
            Button { creating = true } label: {
                Label("Create “\(query)”", systemImage: "plus.circle.fill")
                    .font(.body.weight(.medium))
            }
        }
        .listStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search or add an exercise", text: $query)
                .focused($searchFocused)
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = ""; searchFocused = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: Capsule())
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Chalk")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Type the name of a lift below to add it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
