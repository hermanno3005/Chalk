import SwiftUI

/// Creating an exercise: **a name field and a two-way segmented control** (SPEC §7.3).
///
/// No group is asked for — new exercises land in Ungrouped and are filed later (§7.2) —
/// and no increment. Nothing else.
///
/// The gym and make fields belong to the *Gym machine* branch and do not exist until you
/// pick it; they arrive with gym-bound exercises (#27). Until then picking *Gym machine*
/// records the kind and nothing more, which is exactly what the schema holds: a machine
/// is a separate row, made when there is a gym to make it at.
struct CreateExerciseSheet: View {
    /// Prefilled when the sheet was opened from a search that found nothing.
    let seedName: String
    let onCreate: (String, ExerciseKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var kind: ExerciseKind = .freeWeight
    @FocusState private var nameFocused: Bool

    init(seedName: String = "", onCreate: @escaping (String, ExerciseKind) -> Void) {
        self.seedName = seedName
        self.onCreate = onCreate
        _name = State(initialValue: seedName)
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
                    Picker("Kind", selection: $kind) {
                        Text("Free weight").tag(ExerciseKind.freeWeight)
                        Text("Gym machine").tag(ExerciseKind.gymBound)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Does the load transfer between gyms?")
                } footer: {
                    // The test, stated on whichever option is showing. It is the whole
                    // distinction: transferability, not whether the thing is colloquially
                    // a machine — a cable stack is gym-bound.
                    Text(kind == .gymBound
                         ? "No — the weight means something different at each gym, so its numbers are kept per machine."
                         : "Yes — 60 kg is 60 kg wherever you lift it, so its numbers are kept together.")
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
                        onCreate(trimmedName, kind)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            // Opened from the search field, the name is already typed — the keyboard is
            // only in the way.
            .task { nameFocused = seedName.isEmpty }
        }
        .presentationDetents([.medium, .large])
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            CreateExerciseSheet { _, _ in }
        }
}
