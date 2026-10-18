import SwiftUI

/// The erg detail screen (SPEC §13.8) — **bare for now**: the erg's name, §5.4's empty
/// state, the Log bar into the lap-list sheet (§13.7), and an overflow of its lifetime
/// operations. The zone line and the readout join it with the detail screen.
struct ErgDetailView: View {
    /// Held in `@State` for the life of the push, as `ExerciseDetailView`'s model is.
    @State var model: ErgDetailModel

    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var draftName = ""
    @State private var changingUnit = false
    @State private var confirmingDelete = false
    @State private var logging: LapListModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // §5.4: no chart, no axes, no readout — short text.
            if model.entryCount == 0 {
                Text("Nothing logged yet.")
                    .font(.title3.weight(.medium))
                Text("Log a block and what you held in each zone starts here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { logBar }
        .sheet(item: $logging) { LapListSheet(model: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        draftName = model.name
                        renaming = true
                    }
                    // **Absent, not disabled**, once the erg has an entry (SPEC §13.6).
                    if model.canChangeUnit {
                        Button("Change unit…", systemImage: "ruler") { changingUnit = true }
                    }
                    Button("Delete erg", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .alert("Rename", isPresented: $renaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { model.rename(to: draftName) }
        }
        .confirmationDialog("Change unit", isPresented: $changingUnit, titleVisibility: .visible) {
            ForEach(ErgUnit.allCases.filter { $0 != model.unit }, id: \.self) { unit in
                Button(unit.pickerTitle) { model.changeUnit(to: unit) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Now \(model.unit?.pickerTitle ?? "none"). The unit locks once you log on this erg.")
        }
        .confirmationDialog(
            model.deleteConfirmation,
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                model.delete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var logBar: some View {
        Button {
            logging = model.logSheet()
        } label: {
            Text("Log")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
