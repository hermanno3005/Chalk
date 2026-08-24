// PROTOTYPE — throwaway. Round two of https://github.com/hermanno3005/Chalk/issues/8
//
// Round one picked C — resume card, tiles, type to find. The dev's note: the flat
// grid "feels unordered", and wants exercises grouped. Grilling narrowed what the
// grouping is *for* — it is presentation, not navigation. It does not have to beat
// search at finding things; it has to make the pile legible.
//
// That answer is what makes the design cheap:
//   - Nothing is asked at create time. New exercises land in Ungrouped.
//   - You assign by dragging a tile into a group, later, like arranging app icons.
//   - Groups are your own ordered buckets, not a taxonomy. "Compound" next to "Legs"
//     is incoherent as a classification and entirely fine as a shelf.
//
// Everything above the grouping — the resume card, the tiles, the search field, the
// create-from-search gesture — is held constant from round one's C. The three
// variants disagree only about how the grouping is presented.

import SwiftUI

enum GroupedLayout: String, CaseIterable {
    case sectioned, recentFirst, chips

    var name: String {
        switch self {
        case .sectioned: "C1 — Sectioned grid"
        case .recentFirst: "C2 — Recent, then groups"
        case .chips: "C3 — Group chips filter"
        }
    }
}

// MARK: - Shared pieces (held constant from round one)

/// The round-one resume card, unchanged. It is the reason C won and no variant touches it.
struct ResumeCard: View {
    let exercise: ProtoExercise
    let last: ProtoRecord
    let onLog: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST LOGGED · \(last.date.proAgo.uppercased())")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(exercise.name).font(.title2.weight(.semibold))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(last.reps)").font(.system(size: 44, weight: .bold, design: .rounded))
                Text("×").font(.title3).foregroundStyle(.secondary)
                Text(last.weight.kg).font(.system(size: 44, weight: .bold, design: .rounded))
                Text("kg").font(.title3).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button(action: onLog) { Text("Log again").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Button(action: onOpen) {
                    Image(systemName: "chart.line.uptrend.xyaxis").frame(width: 44)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
    }
}

/// A draggable tile.
///
/// Round three — the dev reported that dragging never started. Two real bugs, not
/// prototype roughness:
///
///  1. **`.draggable` and `.contextMenu` on the same view fight.** Both are driven by
///     long-press, and the context menu won every time. The context menu is gone; the
///     "Log a set" shortcut it carried now lives behind the tile's own menu button in
///     Arrange mode, and on the search-result rows.
///  2. **`.draggable` on a `Button` rarely fires.** The button's gesture claims the
///     press first. The tile is a plain view with a tap gesture now, not a Button.
///
/// Assignment no longer depends on the drag working at all — see `arranging`.
struct ExerciseTile: View {
    let exercise: ProtoExercise
    let arranging: Bool
    let groups: [String]
    let onOpen: () -> Void
    let onLog: () -> Void
    let onAssign: (String?) -> Void
    let onRename: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                if exercise.isGymBound {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 8)).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                if arranging { menuButton }
            }
            Text(exercise.summary ?? "never logged")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        // Plain tap, not a Button — a Button's gesture swallows the drag.
        .onTapGesture { if !arranging { onOpen() } }
        .draggable(exercise.name) {
            Text(exercise.name)
                .font(.subheadline.weight(.medium))
                .padding(10)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    /// The escape hatch. Dragging a tile the length of a 42-tile scroll to reach
    /// Ungrouped was never going to be pleasant even when the gesture works, so
    /// assignment has a plain-menu path that does not involve a gesture at all.
    private var menuButton: some View {
        Menu {
            Picker("Group", selection: Binding(get: { exercise.group ?? "" },
                                               set: { onAssign($0.isEmpty ? nil : $0) })) {
                Text("Ungrouped").tag("")
                ForEach(groups, id: \.self) { Text($0).tag($0) }
            }
            Divider()
            Button("Rename…", systemImage: "pencil", action: onRename)
            Button("Log a set", systemImage: "plus.circle", action: onLog)
            Button("Open", systemImage: "chart.line.uptrend.xyaxis", action: onOpen)
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.footnote)
                .foregroundStyle(.tint)
        }
    }
}

private let tileColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

/// The search field, pinned in thumb reach. Held constant from round one.
struct LibrarySearchBar: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search or add an exercise", text: $query)
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: Capsule())
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
    }
}

// MARK: - The grouped library

struct LibraryGrouped: View {
    @Bindable var store: LibraryStore
    let layout: GroupedLayout
    let onOpen: (ProtoExercise) -> Void
    let onLog: (ProtoExercise) -> Void

    @State private var query = ""
    @State private var creating = false
    @State private var selectedGroup: String? = nil   // C3 only; nil = All
    @State private var collapsed: Set<String> = []    // C2 only
    @State private var dropTarget: String?
    /// Arrange mode puts a menu on every tile, so filing an exercise never depends
    /// on a drag landing.
    /// Screenshot hook: `-autoArrange 1`.
    @State private var arranging = UserDefaults.standard.bool(forKey: "autoArrange")
    /// Screenshot hook: `-autoEditGroups 1`.
    @State private var editingGroups = UserDefaults.standard.bool(forKey: "autoEditGroups")
    @State private var addingGym = false
    @State private var renameTarget: ProtoExercise?
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            if store.exercises.isEmpty {
                emptyState
            } else if !query.isEmpty {
                resultsList
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        if let exercise = store.lastLogged, let last = exercise.lastRecord {
                            ResumeCard(exercise: exercise, last: last,
                                       onLog: { onLog(exercise) }, onOpen: { onOpen(exercise) })
                        }
                        switch layout {
                        case .sectioned: sectioned
                        case .recentFirst: recentFirst
                        case .chips: chipsLayout
                        }
                        footerCount
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 90)
                }
            }
            LibrarySearchBar(query: $query)
        }
        .navigationTitle("Chalk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Arrange mode is a mode, so it gets a visible way out rather than making
            // you go back through the menu you entered by.
            if arranging {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { withAnimation(.snappy) { arranging = false } }
                        .font(.body.weight(.semibold))
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New exercise", systemImage: "plus") { creating = true }
                        Button("Arrange", systemImage: "square.grid.2x2") {
                            withAnimation(.snappy) { arranging = true }
                        }
                        Button("Edit groups", systemImage: "folder.badge.gearshape") {
                            editingGroups = true
                        }
                        Menu("Gym") {
                            ForEach(store.gyms, id: \.self) { gym in
                                Button {
                                    store.currentGym = gym
                                } label: {
                                    if gym == store.currentGym {
                                        Label(gym, systemImage: "checkmark")
                                    } else {
                                        Text(gym)
                                    }
                                }
                            }
                            Divider()
                            Button("Add a gym…", systemImage: "plus") { addingGym = true }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .sheet(isPresented: $creating) {
            CreateExerciseSheet(store: store, seedName: query) { created in
                query = ""
                onOpen(created)
            }
        }
        .sheet(isPresented: $editingGroups) { EditGroupsSheet(store: store) }
        .addGymAlert(store: store, isPresented: $addingGym)
        .alert("Rename exercise", isPresented: Binding(
            get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
        ) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { if let target = renameTarget { store.rename(target, to: renameText) } }
        }
    }

    // MARK: C1 — every group is a section, one long scroll

    private var sectioned: some View {
        VStack(spacing: 20) {
            ForEach(store.groups, id: \.self) { group in
                let items = store.exercises(in: group)
                if !items.isEmpty { section(group, items, showCount: true) }
            }
            if !store.ungrouped.isEmpty {
                section("Ungrouped", store.ungrouped, showCount: true, muted: true)
            }
        }
    }

    // MARK: C2 — recency keeps the top, groups collapse below it

    private var recentFirst: some View {
        VStack(spacing: 20) {
            // A horizontal strip, not a grid. The first cut used the same two-column
            // grid as the sections below it and the top four tiles appeared twice on
            // one screen — recency and grouping competing for the same tiles. A strip
            // reads as a different kind of thing and halves the vertical duplication.
            VStack(alignment: .leading, spacing: 8) {
                header("Recent", count: nil)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(store.byRecency.prefix(6))) { exercise in
                            recentChip(exercise)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            ForEach(store.groups, id: \.self) { group in
                let items = store.exercises(in: group)
                if !items.isEmpty { collapsibleSection(group, items) }
            }
            if !store.ungrouped.isEmpty { collapsibleSection("Ungrouped", store.ungrouped) }
        }
    }

    private func recentChip(_ exercise: ProtoExercise) -> some View {
        Group {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(exercise.summary ?? "never logged")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { onOpen(exercise) }
        .draggable(exercise.name)
    }

    private func collapsibleSection(_ title: String, _ items: [ProtoExercise]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) {
                    if collapsed.contains(title) { collapsed.remove(title) } else { collapsed.insert(title) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: collapsed.contains(title) ? "chevron.right" : "chevron.down")
                        .font(.caption2.weight(.bold))
                    Text(title).font(.footnote.weight(.semibold))
                    Spacer()
                    Text("\(items.count)").font(.caption2).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .dropDestination(for: String.self) { names, _ in
                // Dropping onto a collapsed header still assigns — the whole point of
                // collapsing is that you can drag past a lot of tiles to reach a group.
                for name in names { store.assign(name, to: title == "Ungrouped" ? nil : title) }
                return true
            } isTargeted: { dropTarget = $0 ? title : (dropTarget == title ? nil : dropTarget) }

            if !collapsed.contains(title) {
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    ForEach(items) { tile($0) }
                }
            }
        }
        .padding(dropTarget == title ? 8 : 0)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.accentColor.opacity(dropTarget == title ? 0.12 : 0)))
    }

    // MARK: C3 — one grid, filtered by a chip row

    private var chipsLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", value: nil, count: store.exercises.count)
                    ForEach(store.groups, id: \.self) { group in
                        chip(group, value: group, count: store.exercises(in: group).count)
                    }
                    if !store.ungrouped.isEmpty {
                        chip("Ungrouped", value: "__ungrouped__", count: store.ungrouped.count)
                    }
                }
                .padding(.horizontal, 2)
            }
            LazyVGrid(columns: tileColumns, spacing: 10) {
                ForEach(chipFiltered) { tile($0) }
            }
            if chipFiltered.isEmpty {
                Text("Nothing in this group yet — drag a tile onto the chip to put it here.")
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
    }

    private var chipFiltered: [ProtoExercise] {
        switch selectedGroup {
        case nil: store.byRecency
        case "__ungrouped__": store.ungrouped
        case let group?: store.exercises(in: group)
        }
    }

    private func chip(_ title: String, value: String?, count: Int) -> some View {
        let isOn = selectedGroup == value
        return Button { withAnimation(.snappy) { selectedGroup = value } } label: {
            HStack(spacing: 5) {
                Text(title).font(.subheadline.weight(isOn ? .semibold : .regular))
                Text("\(count)").font(.caption2).opacity(0.6)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isOn ? Color.accentColor : Color(.secondarySystemBackground),
                        in: Capsule())
            .foregroundStyle(isOn ? .white : .primary)
            .overlay(Capsule().strokeBorder(Color.accentColor,
                                            lineWidth: dropTarget == (value ?? "All") ? 2 : 0))
        }
        .buttonStyle(.plain)
        // Assignment without leaving the grid: drag a tile onto a chip.
        .dropDestination(for: String.self) { names, _ in
            for name in names {
                store.assign(name, to: value == "__ungrouped__" || value == nil ? nil : value)
            }
            return true
        } isTargeted: { dropTarget = $0 ? (value ?? "All") : nil }
    }

    // MARK: Section plumbing

    private func section(_ title: String, _ items: [ProtoExercise],
                         showCount: Bool, muted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(title, count: showCount ? items.count : nil, muted: muted)
            LazyVGrid(columns: tileColumns, spacing: 10) {
                ForEach(items) { tile($0) }
            }
        }
        .padding(dropTarget == title ? 8 : 0)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.accentColor.opacity(dropTarget == title ? 0.12 : 0)))
        .dropDestination(for: String.self) { names, _ in
            for name in names { store.assign(name, to: title == "Ungrouped" ? nil : title) }
            return true
        } isTargeted: { dropTarget = $0 ? title : (dropTarget == title ? nil : dropTarget) }
    }

    private func header(_ title: String, count: Int?, muted: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.footnote.weight(.semibold))
            Spacer()
            if let count { Text("\(count)").font(.caption2).foregroundStyle(.tertiary) }
        }
        .foregroundStyle(muted ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
    }

    private func tile(_ exercise: ProtoExercise) -> some View {
        ExerciseTile(exercise: exercise,
                     arranging: arranging,
                     groups: store.groups,
                     onOpen: { onOpen(exercise) },
                     onLog: { onLog(exercise) },
                     onAssign: { store.assign(exercise.name, to: $0) },
                     onRename: { renameTarget = exercise; renameText = exercise.name })
    }

    private var footerCount: some View {
        Text(arranging
             ? "Drag a tile into a group, or use the ••• on any tile"
             : "\(store.exercises.count) exercises · Arrange (••• menu) to file them into groups")
            .font(.caption2).foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity).padding(.top, 2)
    }

    // MARK: Search + empty

    private var resultsList: some View {
        List {
            ForEach(store.matching(query)) { exercise in
                Button { onOpen(exercise) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name).foregroundStyle(.primary)
                            HStack(spacing: 5) {
                                if let group = exercise.group {
                                    Text(group)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color(.tertiarySystemFill), in: Capsule())
                                }
                                Text(exercise.summary ?? "never logged")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Log") { onLog(exercise) }
                            .buttonStyle(.borderless).font(.subheadline.weight(.semibold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button { creating = true } label: {
                Label("Create “\(query)”", systemImage: "plus.circle.fill")
                    .font(.body.weight(.medium))
            }
        }
        .listStyle(.plain)
    }

    /// Round one's weakest screen — a wordmark and a search field. Round two gives the
    /// empty state something to say, borrowed from variant A.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Chalk").font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Add the lifts you actually do. Chalk keeps every rep and weight you log and works out what to load next time.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 36)
            Button { creating = true } label: {
                Text("Add your first exercise").frame(maxWidth: 260)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
