// PROTOTYPE — throwaway.
//
// VARIANT A — Directory. The plain, sectioned, alphabetical iOS list, done properly:
// A–Z sections, a scrub index down the right edge, a search field in the nav bar.
//
// The argument: the library is a *directory*, and its only job is to get out of the
// way. It refuses to log from the list — a row goes to the detail screen and the
// detail screen's Log bar is the one and only way in. One concept, one path, and the
// alphabet means you always know where a given exercise is before you look.
//
// The cost it accepts: cold launch to logging is three taps (row, Log, save), and
// the alphabet is indifferent to what you actually did five minutes ago.

import SwiftUI

struct LibraryVariantADirectory: View {
    @Bindable var store: LibraryStore
    let onOpen: (ProtoExercise) -> Void

    @State private var query = ""
    @State private var creating = false
    @State private var deleteTarget: ProtoExercise?
    @State private var renameTarget: ProtoExercise?
    @State private var renameText = ""

    private var filtered: [ProtoExercise] { store.matching(query) }
    private var isSearching: Bool { !query.isEmpty }

    var body: some View {
        Group {
            if store.exercises.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Exercises")
        .searchable(text: $query, prompt: "Search exercises")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $creating) {
            CreateExerciseSheet(store: store) { onOpen($0) }
        }
        .deleteExerciseConfirmation(target: $deleteTarget) { store.delete($0) }
        .alert("Rename exercise", isPresented: Binding(
            get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
        ) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { if let target = renameTarget { store.rename(target, to: renameText) } }
        }
    }

    // MARK: - List

    @ViewBuilder
    private var list: some View {
        if isSearching {
            List {
                ForEach(filtered) { row($0) }
                if filtered.isEmpty { noMatches }
            }
            .listStyle(.plain)
        } else {
            List {
                ForEach(store.sections, id: \.letter) { section in
                    Section(section.letter) {
                        ForEach(section.exercises) { row($0) }
                    }
                }
            }
            .listStyle(.plain)
            // The scrub index — the thing that makes 42 rows navigable without search.
            .overlay(alignment: .trailing) { alphabetIndex }
        }
    }

    private func row(_ exercise: ProtoExercise) -> some View {
        Button { onOpen(exercise) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let summary = exercise.summary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("no records yet")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
                if exercise.isGymBound {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, isSearching ? 0 : 14) // clear of the scrub index
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleteTarget = exercise } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { renameTarget = exercise; renameText = exercise.name } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.gray)
        }
    }

    private var alphabetIndex: some View {
        VStack(spacing: 1) {
            ForEach(store.sections, id: \.letter) { section in
                Text(section.letter)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.trailing, 3)
    }

    private var noMatches: some View {
        VStack(spacing: 10) {
            Text("No exercise called “\(query)”")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Create “\(query)”") { creating = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .listRowSeparator(.hidden)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No exercises yet")
                .font(.title3.weight(.semibold))
            Text("Add the lifts you actually do. Chalk keeps every rep and weight you log and works out what to load next time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button { creating = true } label: {
                Text("Add your first exercise").frame(maxWidth: 260)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
