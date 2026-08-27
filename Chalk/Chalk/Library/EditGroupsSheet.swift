import SwiftUI

/// **Edit groups** — the sheet behind the library's overflow (SPEC §7.2). Reorder,
/// rename, delete, add.
///
/// **Reordering is the primary action**, which is why the list opens already in edit mode
/// with its grips showing rather than behind an *Edit* button: this list's order *is* the
/// section order on the library screen, and putting compounds at the top is the thing
/// people came here to do. Rename is a tap, because there is nothing else a row's tap
/// could reasonably mean.
///
/// **Deleting a group never deletes exercises** — they fall back to Ungrouped — so the
/// swipe carries no confirmation. Nothing here is destructive to the record, and the one
/// action in Chalk that is (§7.5's merge) is deliberately nowhere near this screen.
struct EditGroupsSheet: View {
    let groups: GroupsModel
    @Environment(\.dismiss) private var dismiss

    @State private var newGroup = ""
    /// The group a tap opened the rename alert over. The group itself rather than its
    /// name: two groups may share a name, and renaming the wrong one is exactly the kind
    /// of quiet mistake a shelf should not be able to make.
    @State private var renaming: ExerciseGroup?
    @State private var renamed = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(groups.groups, id: \.id) { group in
                        row(group)
                    }
                    .onMove { groups.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { offsets in
                        for group in offsets.map({ groups.groups[$0] }) {
                            groups.delete(group)
                        }
                    }
                } header: {
                    Text("Groups")
                } footer: {
                    Text("Drag to reorder — this is the order the sections appear in. Tap to rename. Deleting a group keeps its exercises and moves them to Ungrouped.")
                }

                Section("Add a group") {
                    HStack {
                        TextField("Name", text: $newGroup)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(trimmedNewGroup.isEmpty)
                    }
                }
            }
            // Always arranging: the grips are the point of the screen.
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // `presenting:` hands the group to the action rather than leaving it to read
            // `renaming` back: SwiftUI clears `isPresented` on dismissal *before* running
            // the button, so a rename that reached for the state would find it already
            // nil and quietly do nothing.
            .alert("Rename group", isPresented: Binding(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            ), presenting: renaming) { group in
                TextField("Name", text: $renamed)
                Button("Cancel", role: .cancel) {}
                Button("Rename") { groups.rename(group, to: renamed) }
            }
        }
    }

    private func row(_ group: ExerciseGroup) -> some View {
        HStack {
            Text(group.name)
            Spacer()
            // What is on the shelf, which is the thing you need to know before deleting
            // one — and the count a delete does *not* take with it.
            Text("\(group.exercises?.count ?? 0)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            renamed = group.name
            renaming = group
        }
    }

    private var trimmedNewGroup: String {
        newGroup.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Adds the typed group and clears the field, so a second one is another two taps
    /// rather than a select-all first.
    private func add() {
        guard groups.create(named: newGroup) != nil else { return }
        newGroup = ""
    }
}
