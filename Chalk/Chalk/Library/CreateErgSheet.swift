import SwiftData
import SwiftUI

/// Creating an erg (SPEC §13.6): **name, unit, transferable or gym-bound, and group** —
/// reached from `+`, *Create it* and the endurance empty state.
///
/// - **The name has no suggestions.** Chalk keeps no vocabulary of machines, and no back
///   door to presets.
/// - **The unit starts on none, and Add stays disabled until one is chosen** — `NewErg`
///   holds the rule. Chalk never guesses a unit, because once the erg has entries a unit
///   has no repair.
/// - **Gym-bound is the starting answer**, the cheaper mistake. Unlike §7.3, it reveals
///   no machine fields: the first log resolves the machine.
/// - **The group** is §7.3's picker over the endurance groups, Ungrouped last and
///   selected.
struct CreateErgSheet: View {
    /// The endurance groups, in the order you arranged them.
    let groups: GroupsModel
    let onCreate: (NewErg) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: NewErg
    @FocusState private var nameFocused: Bool
    private let seedName: String

    init(seedName: String = "", groups: GroupsModel, onCreate: @escaping (NewErg) -> Void) {
        self.seedName = seedName
        self.groups = groups
        self.onCreate = onCreate
        _draft = State(initialValue: NewErg(name: seedName))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Erg name", text: $draft.name)
                        .focused($nameFocused)
                        .font(.title3)
                        .textInputAutocapitalization(.words)
                        // No suggestions, from the keyboard either (SPEC §13.6).
                        .autocorrectionDisabled()
                    Picker("Group", selection: $draft.groupID) {
                        ForEach(groups.groups, id: \.id) { group in
                            Text(group.name).tag(UUID?.some(group.id))
                        }
                        Text(LibraryLayout.ungroupedTitle).tag(UUID?.none)
                    }
                }

                Section {
                    Picker("Unit", selection: $draft.unit) {
                        // Starts here, and Add waits until it is left.
                        Text("Choose").tag(ErgUnit?.none)
                        ForEach(ErgUnit.allCases, id: \.self) { unit in
                            Text(unit.pickerTitle).tag(ErgUnit?.some(unit))
                        }
                    }
                } footer: {
                    Text("What the console shows, and what you set. It cannot change once you have logged on this erg.")
                }

                Section {
                    Picker("Kind", selection: $draft.kind) {
                        Text("Transferable").tag(ExerciseKind.freeWeight)
                        Text("Gym-bound").tag(ExerciseKind.gymBound)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    // The test itself, under whichever option is showing (SPEC §13.6).
                    Text(draft.kind == .gymBound
                         ? "Does the same number mean the same thing on every one of these machines, anywhere? No — so its numbers are kept per machine."
                         : "Does the same number mean the same thing on every one of these machines, anywhere? Yes — so its numbers are kept together, at every gym.")
                }
            }
            .navigationTitle("New erg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate(draft)
                        dismiss()
                    }
                    .disabled(!draft.canSave)
                }
            }
            // Opened from the search field, the name is already typed.
            .task { nameFocused = seedName.isEmpty }
        }
        .presentationDetents([.medium, .large])
    }
}

extension ErgUnit {
    /// The unit as the create sheet's picker offers it.
    var pickerTitle: String {
        switch self {
        case .speed: "Speed (km/h)"
        case .watts: "Watts"
        case .split: "Split (/500 m)"
        case .level: "Level"
        }
    }
}

#Preview {
    CreateErgPreview.view()
}

private enum CreateErgPreview {
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
        SuggestedGroups.seedIfNeeded(.endurance, in: context, defaults: defaults)
        return AnyView(
            Color.clear.sheet(isPresented: .constant(true)) {
                CreateErgSheet(groups: GroupsModel(context: context, half: .endurance)) { _ in }
            }
        )
    }
}
