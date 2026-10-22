import SwiftData
import SwiftUI

/// Settings (ADR-0005): the heart-rate zones, and *Make a backup* (ADR-0010), reached from
/// *Settings…* in the home overflow and belonging to neither half.
///
/// Four whole-bpm fields, Z2 to Z5. Z1 is written out rather than typed, because it has no
/// floor of its own — it is everything below Z2. Save stays disabled until the four make a
/// set of zones; there is no clear.
///
/// *Make a backup* hands one readable file of everything Chalk holds to the share sheet. It
/// backs up the zones as saved, not as typed: Save closes the sheet, so what is typed here
/// is never saved while the row is on screen.
struct SettingsSheet: View {
    let model: SettingsModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Z1") {
                        Text(model.lowerBounds[0].map { "below \($0) bpm" } ?? "below Z2")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.lowerBounds.indices, id: \.self) { index in
                        LabeledContent("Z\(index + 2)") {
                            HStack(spacing: 4) {
                                TextField("from", text: bound(index))
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .focused($focused, equals: index)
                                Text("bpm")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Heart-rate zones")
                } footer: {
                    Text("The lowest heart rate of each zone, in whole bpm, from your watch or a lactate test. Each is between 40 and 230 and higher than the one before. Z5 has no ceiling.")
                }
                Section {
                    ShareLink(item: model.backup, preview: SharePreview("Chalk backup")) {
                        Label("Make a backup", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("One file holding every entry, exercise, erg, gym, machine and goal, and your zones. Keep it off the phone, in Files or on a Mac.")
                }
            }
            .onDisappear(perform: model.close)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.save()
                        dismiss()
                    }
                    .disabled(!model.canSave)
                }
            }
        }
    }

    /// One field as text: digits only, at most three, blank for `nil`.
    private func bound(_ index: Int) -> Binding<String> {
        Binding(
            get: { model.lowerBounds[index].map(String.init) ?? "" },
            set: { typed in
                model.lowerBounds[index] = Int(String(typed.filter { $0.isASCII && $0.isNumber }.prefix(3)))
            }
        )
    }
}

#Preview {
    SettingsSheet(model: SettingsModel(
        defaults: UserDefaults(suiteName: "chalk-preview-\(UUID().uuidString)")!,
        container: try! ModelContainer(
            for: Schema(versionedSchema: ChalkSchemaV1.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    ))
}
