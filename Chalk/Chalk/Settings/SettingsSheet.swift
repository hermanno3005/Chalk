import SwiftData
import SwiftUI

/// Settings (ADR-0005): the heart-rate zones, the units, *Make a backup* and *Restore from
/// a backup* (ADR-0010), reached from *Settings…* in the home overflow and belonging to
/// neither half.
///
/// Four whole-bpm fields, Z2 to Z5. Z1 is written out rather than typed, because it has no
/// floor of its own — it is everything below Z2. Save stays disabled until the four make a
/// set of zones; there is no clear.
///
/// *Make a backup* hands one readable file of everything Chalk holds to the share sheet. It
/// backs up the zones as saved, not as typed: Save closes the sheet, so what is typed here
/// is never saved while the row is on screen.
///
/// *Units* shows the weight unit and the distance unit and changes either. With nothing yet
/// written on that scale, a pick is just a change. Once there is, it asks first and offers
/// **relabel**, which keeps every number (SPEC §15.2, ADR-0009); declining leaves the
/// picker where it was, since it only ever shows the unit stored.
///
/// *Restore from a backup* picks a file from Files and replaces everything with it, asking
/// first over a library that is not empty. Once it has, the app reopens on the restored
/// library, which closes Settings.
struct SettingsSheet: View {
    let model: SettingsModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.reopenLibrary) private var reopenLibrary
    @FocusState private var focused: Int?
    @State private var pickingBackup = false

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
                    Picker("Weights", selection: Binding(get: { model.weightUnit }, set: model.change(weightsTo:))) {
                        ForEach(WeightUnit.allCases, id: \.self) { Text($0.symbol) }
                    }
                    Picker("Distances", selection: Binding(get: { model.distanceUnit }, set: model.change(distancesTo:))) {
                        ForEach(DistanceUnit.allCases, id: \.self) { Text($0.name) }
                    }
                } header: {
                    Text("Units")
                }
                Section {
                    ShareLink(item: model.backup, preview: SharePreview("Chalk backup")) {
                        Label("Make a backup", systemImage: "square.and.arrow.up")
                    }
                    Button("Restore from a backup…", systemImage: "square.and.arrow.down") {
                        pickingBackup = true
                    }
                } footer: {
                    Text("One file holding every entry, exercise, erg, gym, machine and goal, and your zones. Keep it off the phone, in Files or on a Mac. Restoring one replaces everything Chalk holds.")
                }
            }
            .fileImporter(isPresented: $pickingBackup, allowedContentTypes: [.json]) { picked in
                guard case .success(let url) = picked else { return }
                model.restore(contentsOf: url)
            }
            .alert(
                model.unitChange?.title ?? "",
                // Cleared by the buttons alone, as the restore question is.
                isPresented: Binding(get: { model.unitChange != nil }, set: { _ in }),
                presenting: model.unitChange
            ) { change in
                Button(change.relabelLabel, action: model.relabel)
                Button("Cancel", role: .cancel, action: model.cancelUnitChange)
            } message: { change in
                Text(change.message)
            }
            .alert(
                "Restore this backup?",
                // Cleared by the buttons alone, so dismissing never races the answer.
                isPresented: Binding(get: { model.restoreConfirmation != nil }, set: { _ in }),
                presenting: model.restoreConfirmation
            ) { _ in
                Button("Restore", role: .destructive, action: model.confirmRestore)
                Button("Cancel", role: .cancel, action: model.cancelRestore)
            } message: { confirmation in
                Text(confirmation)
            }
            .alert(
                "Can't restore",
                isPresented: Binding(get: { model.restoreFailure != nil }, set: { if !$0 { model.restoreFailure = nil } }),
                presenting: model.restoreFailure
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { failure in
                Text(failure)
            }
            .onChange(of: model.restored) {
                if model.restored { reopenLibrary() }
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
