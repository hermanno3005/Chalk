// PROTOTYPE — throwaway. Round four of https://github.com/hermanno3005/Chalk/issues/8
//
// Groups are *user-owned* — that was the decision that made drag-to-assign coherent
// (a shelf you arranged, not a taxonomy). A user-owned thing you cannot rename,
// reorder or delete is not actually user-owned, so "Edit groups" stops being a stub.
//
// Order matters here in a way it does not in most settings screens: the section order
// on the library screen *is* this list's order, and the dev's original ask was
// "compounds at the top". So reordering is the primary action, not an afterthought.

import SwiftUI

struct EditGroupsSheet: View {
    @Bindable var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var newGroup = ""
    @State private var renaming: String?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.groups, id: \.self) { group in
                        HStack {
                            Text(group)
                            Spacer()
                            Text("\(store.exercises(in: group).count)")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { renaming = group; renameText = group }
                    }
                    .onMove { store.moveGroup(from: $0, to: $1) }
                    .onDelete { indexSet in
                        for index in indexSet { store.deleteGroup(store.groups[index]) }
                    }
                } header: {
                    Text("Groups")
                } footer: {
                    Text("Drag to reorder — this is the order the sections appear in. Tap to rename. Deleting a group keeps its exercises and moves them to Ungrouped.")
                }

                Section("Add a group") {
                    HStack {
                        TextField("Name", text: $newGroup)
                        Button("Add") {
                            store.addGroup(newGroup)
                            newGroup = ""
                        }
                        .disabled(newGroup.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if !store.ungrouped.isEmpty {
                    Section {
                        Text("\(store.ungrouped.count) exercises are not in any group.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .alert("Rename group", isPresented: Binding(
                get: { renaming != nil }, set: { if !$0 { renaming = nil } })
            ) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Rename") { if let old = renaming { store.renameGroup(old, to: renameText) } }
            }
        }
    }
}

/// Adding a gym had no path at all — the create sheet offered "Add a gym…" and did
/// nothing with it. Gyms are now held explicitly on the store, so a gym added here
/// survives having no machines attached to it yet.
struct AddGymAlert: ViewModifier {
    @Bindable var store: LibraryStore
    @Binding var isPresented: Bool
    @State private var name = ""

    func body(content: Content) -> some View {
        content.alert("Add a gym", isPresented: $isPresented) {
            TextField("Gym name", text: $name)
            Button("Cancel", role: .cancel) { name = "" }
            Button("Add") {
                store.addGym(name)
                name = ""
            }
        } message: {
            Text("Machine records are kept per gym, so the name only has to mean something to you.")
        }
    }
}

extension View {
    func addGymAlert(store: LibraryStore, isPresented: Binding<Bool>) -> some View {
        modifier(AddGymAlert(store: store, isPresented: isPresented))
    }
}
