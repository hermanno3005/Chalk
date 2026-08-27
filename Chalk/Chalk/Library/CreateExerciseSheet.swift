import SwiftData
import SwiftUI

/// Creating an exercise: **a name field and a two-way segmented control** (SPEC §7.3),
/// with the gym and make fields revealed by *Gym machine* and by nothing else.
///
/// No group is asked for — new exercises land in Ungrouped and are filed later (§7.2) —
/// and no increment. Nothing else.
///
/// **Progressive disclosure, not a disabled row**: the gym and make fields do not exist
/// until you pick *Gym machine*, because they are meaningless for an exercise whose load
/// transfers. Each option carries the test as its footer — *does the load transfer
/// between gyms?* — which is the whole distinction, and the reason a cable stack is
/// gym-bound despite not being a machine colloquially.
struct CreateExerciseSheet: View {
    /// Prefilled when the sheet was opened from a search that found nothing.
    let seedName: String
    /// The gyms, for the gym-bound branch — and the third of the three doors `New gym…`
    /// opens behind (§7.4).
    let gyms: GymsModel
    let onCreate: (String, ExerciseKind, Gym?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var kind: ExerciseKind = .freeWeight
    /// The gym the first machine is made at, **held as its id**: identity is `Gym.id`
    /// (SPEC §7.4), and a picker tag has to stay the same value across the rebuild that
    /// creating a gym causes. Seeded with the current gym — creating an exercise is
    /// something you do standing in front of the thing.
    @State private var gymID: UUID?
    /// What is written on the stack — the sheet's *make* field, and the machine's
    /// `manufacturer` once it exists.
    @State private var manufacturer = ""
    @State private var creatingGym = false
    @FocusState private var nameFocused: Bool

    init(
        seedName: String = "",
        gyms: GymsModel,
        onCreate: @escaping (String, ExerciseKind, Gym?, String?) -> Void
    ) {
        self.seedName = seedName
        self.gyms = gyms
        self.onCreate = onCreate
        _name = State(initialValue: seedName)
        _gymID = State(initialValue: gyms.currentGym?.id)
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
                } footer: {
                    // The test itself, restated under whichever option is showing. It is
                    // the whole distinction: transferability, not whether the thing is
                    // colloquially a machine — a cable stack is gym-bound.
                    Text(kind == .gymBound
                         ? "Does the load transfer between gyms? No — the weight means something different at each gym, so its numbers are kept per machine."
                         : "Does the load transfer between gyms? Yes — 60 kg is 60 kg wherever you lift it, so its numbers are kept together.")
                }

                if kind == .gymBound {
                    machineSection
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
                        onCreate(trimmedName, kind, kind == .gymBound ? gym : nil, manufacturer)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            // Opened from the search field, the name is already typed — the keyboard is
            // only in the way.
            .task { nameFocused = seedName.isEmpty }
            .sheet(isPresented: $creatingGym) {
                // Created here and selected here: you opened this door because the gym
                // you are standing in was not in the list.
                NewGymSheet(gyms: gyms) { gymID = $0.id }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// The gym-bound branch. **Where**, and **what it says on the stack** — the two things
    /// that make a machine, and neither of them is asked for anywhere else at create time.
    @ViewBuilder
    private var machineSection: some View {
        Section {
            Picker("Gym", selection: $gymID) {
                // No gym is a real answer: an exercise can be created at your desk, and
                // the first log makes the machine (§6.4).
                Text("None").tag(UUID?.none)
                ForEach(gyms.gyms, id: \.id) { gym in
                    Text(gym.name).tag(UUID?.some(gym.id))
                }
            }
            Button("New gym…", systemImage: "plus") { creatingGym = true }
            TextField("Make — optional", text: $manufacturer)
                .textInputAutocapitalization(.words)
        } footer: {
            Text(gym == nil
                 ? "Its numbers are kept per machine, so pick the gym you use it at — or leave this and the first entry you log will make the machine."
                 : "What is written on the stack — Hammer Strength, Technogym. One gym can hold several of these and their numbers stay separate.")
        }
    }

    /// The picked gym, resolved from the id the picker holds. A gym that has gone since
    /// the sheet opened resolves to none rather than to a stale row.
    private var gym: Gym? {
        gyms.gyms.first { $0.id == gymID }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    CreateExercisePreview.view()
}

private enum CreateExercisePreview {
    @MainActor
    static func view() -> some View {
        guard
            let container = try? ModelContainer(
                for: Schema(versionedSchema: ChalkSchemaV1.self),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ),
            let defaults = UserDefaults(suiteName: "chalk-preview-\(UUID().uuidString)")
        else {
            return AnyView(Text("No preview store."))
        }
        let context = ModelContext(container)
        context.insert(Gym(name: "Fitness X"))
        context.insert(Gym(name: "Old Barn"))
        let gyms = GymsModel(context: context, defaults: defaults)
        return AnyView(
            Color.clear.sheet(isPresented: .constant(true)) {
                CreateExerciseSheet(gyms: gyms) { _, _, _, _ in }
            }
        )
    }
}
