// PROTOTYPE — throwaway. Answers https://github.com/hermanno3005/Chalk/issues/8
//
// SHARED across all three variants on purpose. The variants disagree about how you
// *find* an exercise and whether you can log from the list; they do not disagree
// about the create form, so varying it would only add noise to the comparison.
//
// The one real question this form answers: how the free-weight / gym-bound flag and
// its machine qualifiers appear without cluttering the common case. The answer tried
// here is progressive disclosure — the gym and machine fields do not exist until you
// say the exercise is gym-bound.

import SwiftUI

struct CreateExerciseSheet: View {
    @Bindable var store: LibraryStore
    /// Prefilled when the sheet was opened from a search field that found nothing.
    var seedName: String = ""
    let onCreated: (ProtoExercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    // Screenshot hook: `-autoGymBound 1` opens with the machine fields disclosed.
    @State private var isGymBound = UserDefaults.standard.bool(forKey: "autoGymBound")
    @State private var gym: String
    @State private var machineLabel = ""
    @FocusState private var nameFocused: Bool

    init(store: LibraryStore, seedName: String = "", onCreated: @escaping (ProtoExercise) -> Void) {
        self.store = store
        self.seedName = seedName
        self.onCreated = onCreated
        _name = State(initialValue: seedName)
        _gym = State(initialValue: store.currentGym)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise name", text: $name)
                        .focused($nameFocused)
                        .font(.title3)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Picker("Kind", selection: $isGymBound) {
                        Text("Free weight").tag(false)
                        Text("Gym machine").tag(true)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    // The test from https://github.com/hermanno3005/Chalk/issues/2 —
                    // does the load transfer between gyms? Cables count as gym-bound.
                    Text(isGymBound
                         ? "The weight means something different at each gym, so records are kept per machine."
                         : "60 kg is 60 kg anywhere. Records are kept together.")
                }

                // Progressive disclosure: none of this exists for the common case.
                if isGymBound {
                    Section("This machine") {
                        Picker("Gym", selection: $gym) {
                            ForEach(store.gyms.isEmpty ? [store.currentGym] : store.gyms, id: \.self) {
                                Text($0).tag($0)
                            }
                            Text("Add a gym…").tag("__new__")
                        }
                        TextField("Make (optional)", text: $machineLabel)
                    }
                }
            }
            .navigationTitle("New exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.add(name: name.trimmingCharacters(in: .whitespaces),
                                  isGymBound: isGymBound, gym: gym, machineLabel: machineLabel)
                        if let created = store.exercises.last { onCreated(created) }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task { nameFocused = seedName.isEmpty }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Shared too. Deleting an exercise destroys its records, and the count is the only
/// thing that makes that concrete — so it goes in the message rather than the fog.
extension View {
    func deleteExerciseConfirmation(
        target: Binding<ProtoExercise?>, onDelete: @escaping (ProtoExercise) -> Void
    ) -> some View {
        confirmationDialog(
            target.wrappedValue.map { "Delete \($0.name)?" } ?? "",
            isPresented: Binding(get: { target.wrappedValue != nil },
                                 set: { if !$0 { target.wrappedValue = nil } }),
            titleVisibility: .visible
        ) {
            if let exercise = target.wrappedValue {
                Button("Delete exercise and \(exercise.records.count) records", role: .destructive) {
                    onDelete(exercise)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let exercise = target.wrappedValue {
                Text(exercise.records.isEmpty
                     ? "It has no records yet."
                     : "Its \(exercise.records.count) records go with it. This cannot be undone.")
            }
        }
    }
}
