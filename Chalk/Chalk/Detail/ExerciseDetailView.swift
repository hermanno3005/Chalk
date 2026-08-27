import SwiftData
import SwiftUI

/// The exercise detail screen (SPEC §5.1). **It has two shapes**: a gym-bound exercise
/// carries the machine qualifier in its nav bar and derives from one machine's entries,
/// and a free-weight one shows **no qualifier at all** — not a disabled one, not a
/// placeholder (§5.3).
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
    @State private var history: HistorySheetModel?
    @State private var flashingConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.hasCurve {
                if let readout = model.readout {
                    // The one way into raw history (SPEC §5.6). A plain tap on the
                    // readout, not a `Button`: the number keeps its own colour, and
                    // nothing on this screen should look tappable twice over. An
                    // unproven cell hands back no sheet, and shows no chevron.
                    ScrubReadout(readout: readout)
                        .contentShape(.rect)
                        .onTapGesture { history = model.historySheet() }
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
            if model.isGymBound {
                ToolbarItem(placement: .topBarTrailing) { qualifier }
            }
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
        .sheet(item: $history) { HistorySheet(model: $0) }
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

    /// The machine qualifier — **gym-bound only** (SPEC §5.3). Switching re-scopes the
    /// screen and re-derives the whole curve, because a gym-bound exercise's rep-maxes
    /// come from one machine's entries and nothing else.
    ///
    /// It is the app's one machine picker, the same rows the log sheet's caption opens
    /// (§6.4). Creating a machine is not offered here: this menu resolves between
    /// machines that exist, and the hole it cannot close belongs where you are standing
    /// at the rack (#28).
    private var qualifier: some View {
        Menu {
            MachinePicker(
                menu: model.machineMenu,
                selected: model.machine,
                onSelect: model.select
            )
        } label: {
            // The machine in scope, said out loud: the number below it means nothing
            // without it. An exercise with no machine yet says so rather than staying
            // blank — the qualifier reads as unset until the first log makes one.
            Label(model.machine?.name ?? "No machine", systemImage: "square.stack.3d.up")
        }
        .disabled(model.machines.isEmpty)
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
    /// implies numbers that do not exist. The machine hint — your numbers on a sibling
    /// machine — is #29.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing logged yet.")
                .font(.title3.weight(.medium))
            Text(emptyDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    /// A gym-bound exercise with no machine yet has nothing to log **onto** — its
    /// numbers are kept per machine and it has none — so the line says that rather than
    /// inviting a tap on a bar that cannot open. The row that makes the first machine
    /// belongs to the log sheet's own picker (§6.4, #28).
    private var emptyDetail: String {
        model.canLog
            ? "Log a lift and your curve starts here."
            : "Its numbers are kept per machine, and it has none yet."
    }

    /// Full width, pinned at the bottom. Opens the log sheet (SPEC §6.1), which for a
    /// free-weight exercise is all the caller has to supply — resolving a machine is
    /// the gym-bound caller's job (§6.4, #28).
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
        // **A gym-bound exercise must resolve a machine** (SPEC §3, invariant 4), and
        // with no machine at all there is nothing for this caller to hand the sheet. The
        // row that makes one mid-log is the sheet's own (§6.4, #28).
        .disabled(!model.canLog)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
