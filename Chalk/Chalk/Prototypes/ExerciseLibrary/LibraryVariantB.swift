// PROTOTYPE — throwaway.
//
// VARIANT B — Recency, with a log shortcut on every row. No alphabet: the list is
// ordered by when you last logged, in three bands — Today, This week, Everything else
// (that last one alphabetical, because past a week recency stops meaning anything).
//
// The argument: you did not open Chalk to browse. You opened it mid-set, and the
// exercise you want is almost always one you touched in the last hour or the last
// week. Every row carries a Log button that opens the winning log sheet directly,
// seeded from that exercise's most recent entry — so cold launch to logged is two
// taps for a repeat, and the detail screen becomes the place you go to *look*, not
// the place you go to *log*.
//
// The cost it accepts: the position of a row changes as you use the app, so you can
// never learn where anything is, and a rarely-used exercise sinks into a long
// alphabetical tail. It also puts two tap targets on every row.

import SwiftUI

struct LibraryVariantBRecency: View {
    @Bindable var store: LibraryStore
    let onOpen: (ProtoExercise) -> Void
    let onLog: (ProtoExercise) -> Void

    @State private var query = ""
    @State private var creating = false
    @State private var deleteTarget: ProtoExercise?

    var body: some View {
        Group {
            if store.exercises.isEmpty {
                emptyState
            } else if !query.isEmpty {
                List { ForEach(store.matching(query)) { row($0) } }
                    .listStyle(.plain)
            } else {
                bandedList
            }
        }
        .navigationTitle("Chalk")
        .searchable(text: $query, prompt: "Search exercises")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { gymMenu }
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $creating) {
            CreateExerciseSheet(store: store) { onOpen($0) }
        }
        .deleteExerciseConfirmation(target: $deleteTarget) { store.delete($0) }
    }

    /// The sticky current gym from https://github.com/hermanno3005/Chalk/issues/2 has
    /// to live *somewhere* — B parks it in the nav bar, where it is visible without
    /// being asked for at log time.
    private var gymMenu: some View {
        Menu {
            ForEach(store.gyms, id: \.self) { gym in
                Button { store.currentGym = gym } label: {
                    if gym == store.currentGym { Label(gym, systemImage: "checkmark") } else { Text(gym) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                Text(store.currentGym).lineLimit(1)
            }
            .font(.subheadline)
        }
    }

    private var bandedList: some View {
        List {
            band("Today", store.today, tint: .green)
            band("This week", store.thisWeek, tint: .blue)
            band("Everything else", store.everythingElse, tint: nil)
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func band(_ title: String, _ exercises: [ProtoExercise], tint: Color?) -> some View {
        if !exercises.isEmpty {
            Section {
                ForEach(exercises) { row($0) }
            } header: {
                HStack(spacing: 6) {
                    if let tint {
                        Circle().fill(tint).frame(width: 6, height: 6)
                    }
                    Text(title)
                    Spacer()
                    Text("\(exercises.count)").foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func row(_ exercise: ProtoExercise) -> some View {
        HStack(spacing: 0) {
            Button { onOpen(exercise) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(exercise.name).font(.body.weight(.medium))
                        if exercise.isGymBound {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    Text(exercise.summary ?? "never logged")
                        .font(.caption)
                        .foregroundStyle(exercise.summary == nil ? .tertiary : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // The whole argument of this variant, in one control.
            Button { onLog(exercise) } label: {
                Text("Log")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleteTarget = exercise } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("Nothing logged yet")
                .font(.title2.weight(.semibold))
            Text("Add an exercise, log a set, and it moves to the top of this list. The things you do most stay where your thumb is.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
            Button { creating = true } label: {
                Label("Add an exercise", systemImage: "plus").frame(maxWidth: 260)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
