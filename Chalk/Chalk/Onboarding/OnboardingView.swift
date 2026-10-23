import SwiftData
import SwiftUI

/// Onboarding (SPEC §15.3): **one screen**, the weight unit, the distance unit and a quieter
/// *Restore from a backup* link, then the library, as before. Shown only while no units are
/// stored, so it is seen once.
///
/// *Restore from a backup* is the team-switch day's one tap: it restores over the empty
/// library and takes both units from the file. Either way, the app then opens on the library
/// as a relaunch would.
struct OnboardingView: View {
    let model: OnboardingModel

    @Environment(\.reopenLibrary) private var reopenLibrary
    @State private var pickingBackup = false

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 12) {
            Spacer()
            Text("Pick your units")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Chalk writes every weight and speed in these. You can change them later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("Weights")
                    Picker("Weights", selection: $model.weightUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { Text($0.symbol) }
                    }
                }
                GridRow {
                    Text("Distances")
                    Picker("Distances", selection: $model.distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { Text($0.name) }
                    }
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .padding(.top, 12)
            Button(action: model.pick) {
                Text("Continue")
                    .frame(maxWidth: 260)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 18)
            Spacer()
            Button("Restore from a backup…") {
                pickingBackup = true
            }
            .font(.subheadline)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .fileImporter(isPresented: $pickingBackup, allowedContentTypes: [.json]) { picked in
            guard case .success(let url) = picked else { return }
            model.restore(contentsOf: url)
        }
        .alert(
            "Restore this backup?",
            // Cleared by the buttons alone, as Settings' restore question is.
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
        // Units are stored either way, and a restore has replaced the rows besides.
        .onChange(of: model.unitsStored) {
            if model.unitsStored { reopenLibrary() }
        }
    }
}

#Preview {
    OnboardingView(model: OnboardingModel(
        defaults: UserDefaults(suiteName: "chalk-preview-\(UUID().uuidString)")!,
        container: try! ModelContainer(
            for: Schema(versionedSchema: ChalkSchemaV1.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    ))
}
