import SwiftUI

/// `New gym…`, the same one field behind all three creation doors — the library's Gym
/// menu, the create-exercise sheet, and the log sheet's picker (SPEC §7.4).
///
/// **A near name warns; it never blocks.** Duplicates are prevented rather than merged —
/// there is no gym merge, and the repair for one that slipped through is moving each
/// machine across by hand — but two gyms really can be called *Fitness X*, so the warning
/// is the user's to overrule.
struct NewGymSheet: View {
    let gyms: GymsModel
    let onCreate: (Gym) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Gym name", text: $name)
                        .focused($nameFocused)
                        .font(.title3)
                        .textInputAutocapitalization(.words)
                } footer: {
                    if let match = gyms.nearMatch(for: name) {
                        Label(
                            "You already have a gym called \(match.name). Create this one only if it is a different place.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("New gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let gym = gyms.create(named: name) { onCreate(gym) }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task { nameFocused = true }
        }
        .presentationDetents([.medium])
    }
}
