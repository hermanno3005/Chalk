import SwiftData
import SwiftUI

/// The exercise detail screen (SPEC §5.1). Free-weight only: the machine qualifier is
/// #26, and its absence here is deliberate — the screen has two shapes, and a
/// free-weight exercise shows no qualifier at all, not a disabled one (§5.3).
///
/// Top to bottom: the scrub readout, the 150 pt curve, empty space, the Log bar. **The
/// empty space ships empty**: it keeps the Log bar high and thumb-reachable, and is not
/// a slot for a recent-entries list or a rep-max strip.
struct ExerciseDetailView: View {
    /// Held in `@State` for the life of the push: `navigationDestination` rebuilds its
    /// destination as the library behind it changes, and the model handed to every
    /// rebuild after the first is dropped — which is what keeps the sticky selection
    /// where the finger left it.
    @State var model: ExerciseDetailModel

    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var draftName = ""
    @State private var confirmingDelete = false
    @State private var logging = false
    @State private var flashingConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.hasCurve {
                if let readout = model.readout {
                    ScrubReadout(readout: readout)
                }
                StrengthCurve(
                    curve: model.curve,
                    selectedReps: model.selectedReps,
                    onSelect: model.select
                )
            } else {
                empty
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        // The back button is the `NavigationStack`'s own — nothing here hides it, and
        // nothing here draws a second one.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        draftName = model.name
                        renaming = true
                    }
                    // *Change kind* is §8, and there is deliberately no *edit records*
                    // item: the curve is how you find a bad entry.
                    Button("Delete exercise", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { logBar }
        .overlay(alignment: .bottom) { confirmation }
        .sheet(isPresented: $logging) {
            LogSheet(model: model.logSheet { flashConfirmation() })
        }
        .alert("Rename", isPresented: $renaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { model.rename(to: draftName) }
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

    /// The brief confirmation the screen flashes after a save, while the curve behind
    /// it has already moved (SPEC §6.7). It says the entry landed and then gets out of
    /// the way — there is nothing to undo here and nothing to tap.
    @ViewBuilder
    private var confirmation: some View {
        if flashingConfirmation {
            Label("Logged", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: .capsule)
                .padding(.bottom, 24)
                .transition(.opacity)
                // Nothing to tap and nothing to undo — but it is still the only word
                // the screen says about a write, so it is not hidden from VoiceOver.
                .allowsHitTesting(false)
        }
    }

    private func flashConfirmation() {
        withAnimation(.snappy) { flashingConfirmation = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeOut) { flashingConfirmation = false }
        }
    }

    /// Zero entries: short text where the chart would be, and the Log bar beneath it
    /// (SPEC §5.4). No axes, no flat line at zero, no ghost — a chart frame with no data
    /// implies numbers that do not exist. The machine hint belongs to gym-bound
    /// exercises and lands with the qualifier (#26).
    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing logged yet.")
                .font(.title3.weight(.medium))
            Text("Log a lift and your curve starts here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    /// Full width, pinned at the bottom. Opens the log sheet (SPEC §6.1), which for a
    /// free-weight exercise is all the caller has to supply — resolving a machine is
    /// the gym-bound caller's job (§6.4, #26).
    private var logBar: some View {
        Button {
            logging = true
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
