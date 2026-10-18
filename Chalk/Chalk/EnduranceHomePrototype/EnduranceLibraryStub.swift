import SwiftUI

// PROTOTYPE — the endurance half's home screen, **held constant across every variant**.
// The variants disagree about how you get here, not about what is here. It is §7's
// shape minus groups: a resume card, a flat recency-ordered tile grid, search pinned in
// thumb reach with *Create it*. Six built-in ergs plus your own is under the twenty-ish
// where strength's groups start paying (§7.2), so it has none.

struct EnduranceLibraryStub: View {
    let ergs: [ProtoErg]
    let gyms: GymsModel
    var title = "Endurance"
    var principal: AnyView?
    var titleMenu: AnyView?

    @State private var opened: [ProtoErg] = []
    @State private var query = ""
    @State private var logging: ProtoErg?
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack(path: $opened) {
            content
                .scrollDismissesKeyboard(.interactively)
                .navigationDestination(for: ProtoErg.self) { ErgDetailStub(erg: $0) }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .modifier(StubTitleMenu(menu: titleMenu))
                .toolbar {
                    if let principal {
                        ToolbarItem(placement: .principal) { principal }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New erg", systemImage: "plus") {}
                    }
                    ToolbarItem(placement: .topBarTrailing) { overflow }
                }
                .safeAreaInset(edge: .bottom) {
                    LibrarySearchField(query: $query, isFocused: $searchFocused, prompt: "Search or add an erg")
                }
                .sheet(item: $logging) { LogIntervalStub(erg: $0) }
        }
    }

    /// Round two: groups in your order, Ungrouped last, tiles by recency within each —
    /// §7.1 exactly. Empty groups have no section.
    private var sections: [(title: String, ergs: [ProtoErg])] {
        let filed = ErgGroups.suggested.map { name in (title: name, ergs: ergs.filter { $0.group == name }) }
        let ungrouped = (title: "Ungrouped", ergs: ergs.filter { $0.group == nil })
        return (filed + [ungrouped]).filter { !$0.ergs.isEmpty }
    }

    /// Arrange and Edit groups, exactly as strength's, over the endurance set. The Gym menu is the
    /// **same** menu over the **same** gyms: current gym is shared by both halves (#93).
    private var overflow: some View {
        Menu {
            Section {
                Button("Arrange", systemImage: "square.grid.2x2") {}
                Button("Edit groups…", systemImage: "folder") {}
            }
            GymMenu(gyms: gyms, onNewGym: {}, onManageGyms: {})
            Section { SettingsRow() }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var content: some View {
        if ergs.isEmpty {
            EmptyErgsView()
        } else if !query.isEmpty {
            List {
                ForEach(ergs.filter { $0.name.localizedCaseInsensitiveContains(query) }) { erg in
                    Button(erg.name) { opened.append(erg) }
                        .foregroundStyle(.primary)
                }
                if !ergs.contains(where: { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }) {
                    Label("Create “\(query)”", systemImage: "plus.circle.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.tint)
                }
            }
            .listStyle(.plain)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let last = ergs.first, let interval = last.last {
                        ErgResumeCard(erg: last, interval: interval, onOpen: { opened.append(last) }) {
                            logging = last
                        }
                    }
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(section.title).font(.footnote.weight(.semibold))
                                Spacer()
                                Text("\(section.ergs.count)").font(.caption2).foregroundStyle(.tertiary)
                            }
                            .foregroundStyle(section.title == "Ungrouped" ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                            ErgGrid(ergs: section.ergs) { opened.append($0) }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }
}

/// The ergs as tiles, two columns, most recent first. Shared by the endurance half and
/// variant D's Ergs section.
struct ErgGrid: View {
    let ergs: [ProtoErg]
    let onOpen: (ProtoErg) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(ergs) { erg in
                ErgTile(erg: erg).onTapGesture { onOpen(erg) }
            }
        }
    }
}

/// An erg tile — strength's tile with an interval for a subtitle. A gym-bound erg with
/// machines at four gyms is still **one** tile; the machine is resolved on the detail
/// screen and the log sheet, as it is for a gym-bound exercise.
struct ErgTile: View {
    let erg: ProtoErg

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(erg.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2, reservesSpace: true)
            if let last = erg.last {
                Text(last.tileText)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// The last interval you did, with **Log again** — strength's resume card, in
/// endurance's words.
struct ErgResumeCard: View {
    let erg: ProtoErg
    let interval: ProtoInterval
    let onOpen: () -> Void
    let onLogAgain: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(erg.name)
                    .font(.title3.weight(.semibold))
                Text(interval.cardText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            Button("Log again", action: onLogAgain)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct EmptyErgsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Calibrate the machines you train on")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Log an interval as time, what you set and the heart rate it cost. Chalk works out what to set on this machine to hit a zone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button {} label: { Text("Add your first erg").frame(maxWidth: 260) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// `Settings…` (#92): app-wide, in the overflow, present in both halves. A stub here.
struct SettingsRow: View {
    var body: some View {
        Button("Settings…", systemImage: "gearshape") {}
    }
}

/// Placement only — the erg detail screen is [How is the derived number presented?].
struct ErgDetailStub: View {
    let erg: ProtoErg

    var body: some View {
        List {
            Section {
                Text("Erg detail is out of this prototype — see *How is the derived number presented?* (#98).")
                    .foregroundStyle(.secondary)
            }
            Section(erg.isTransferable ? "Transferable — no machines" : "Machines") {
                ForEach(erg.machines, id: \.self) { Text($0) }
            }
        }
        .navigationTitle(erg.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Placement only — logging is [How is an interval logged?].
struct LogIntervalStub: View {
    let erg: ProtoErg

    var body: some View {
        VStack(spacing: 8) {
            Text("Log \(erg.name)").font(.headline)
            Text("See *How is an interval logged?* (#97).")
                .foregroundStyle(.secondary)
        }
        .presentationDetents([.medium])
    }
}

private struct StubTitleMenu: ViewModifier {
    let menu: AnyView?

    func body(content: Content) -> some View {
        if let menu {
            content.toolbarTitleMenu { menu }
        } else {
            content
        }
    }
}
