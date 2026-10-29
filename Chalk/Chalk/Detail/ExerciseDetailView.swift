import SwiftData
import SwiftUI

/// The exercise detail screen (SPEC §5.1). **It has two shapes**: a gym-bound exercise
/// carries the machine qualifier in its nav bar and derives from one machine's entries,
/// and a free-weight one shows **no qualifier at all** — not a disabled one, not a
/// placeholder (§5.3).
///
/// Top to bottom, as Trade Republic's stock screen (§15.4): the name in grey over the
/// number and its `× N`, the goal line, the curve, two rows, empty space, the Log bar.
/// **The empty space ships empty**: it keeps the Log bar high and thumb-reachable, and is
/// not a slot for a recent-entries list or a rep-max strip.
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
    /// `Change kind` in flight: the confirmation for the flip that needs no machine,
    /// and the prompt for the one that does (SPEC §8).
    @State private var confirmingKindChange = false
    @State private var changingKind = false
    @State private var logging = false
    @State private var history: HistorySheetModel?
    @State private var goalSheet: GoalSheetModel?
    @State private var flashingConfirmation = false

    var body: some View {
        DetailBody { content }
        .chalkScreen()
        // The name is the readout's (SPEC §5.1); kept as the title for the back menu
        // and VoiceOver, never drawn in the bar.
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
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
                    // The free-weight ↔ gym-bound flip (SPEC §8). One verb either
                    // way: which direction it runs is the kind the exercise is now,
                    // never something to choose. There is deliberately no *edit
                    // records* item — the curve is how you find a bad entry.
                    Button("Change kind", systemImage: "arrow.left.arrow.right") {
                        if model.kindChange.needsAMachine {
                            changingKind = true
                        } else {
                            confirmingKindChange = true
                        }
                    }
                    // Setting, changing and clearing all happen in the goal sheet;
                    // clearing is kept out of here, which holds lifetime operations.
                    if let goalMenuLabel = model.goalMenuLabel {
                        Button(goalMenuLabel, systemImage: "scope") {
                            goalSheet = model.goalSheet()
                        }
                    }
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
        .sheet(item: $goalSheet) { GoalSheet(model: $0) }
        .alert("Rename", isPresented: $renaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { model.rename(to: draftName) }
        }
        // The flip that asks for a machine — free-weight → gym-bound with entries or a
        // goal to place. Answering it is the whole decision; there is no second
        // confirmation.
        .sheet(isPresented: $changingKind) {
            ChangeKindSheet(change: model.kindChange, gyms: model.gyms) { gym, name in
                model.makeGymBound(at: gym, named: name)
            }
        }
        // The flip that asks nothing else: pooling, which names the consequence out
        // loud, and the flip of an exercise with nothing logged and no goal, which has
        // nothing to place and so nothing to ask about.
        .confirmationDialog(
            model.kindChange.question,
            isPresented: $confirmingKindChange,
            titleVisibility: .visible
        ) {
            // Destructive one way only: pooling hard-deletes the machine rows, and
            // going the other way creates one and takes nothing.
            Button(
                model.kindChange.confirmButton,
                role: model.isGymBound ? .destructive : nil
            ) {
                if model.isGymBound {
                    model.makeFreeWeight()
                } else {
                    model.makeGymBound()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.kindChange.detail)
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

    /// Top to bottom, as the type's doc says; `DetailBody` decides whether it scrolls.
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let readout = model.readout {
                // One of two ways into raw history (SPEC §5.6), with the first row. A
                // plain tap, not a `Button`: the number keeps its own colour. An
                // unproven cell hands back no sheet.
                DetailHead(
                    name: model.name,
                    number: readout.weightWithUnit,
                    aside: readout.aside,
                    dimmed: readout.weight == nil,
                    opensHistory: readout.weight != nil
                )
                .onTapGesture { history = model.historySheet() }
                goalLine
                    .padding(.top, 12)
                StrengthCurve(
                    curve: model.curve,
                    selectedReps: model.selectedReps,
                    onSelect: model.select
                )
                .detailChart()
                .padding(.top, 40)
                rows(readout)
                    .padding(.top, 28)
            } else {
                DetailHead(name: model.name)
                empty
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The machine qualifier — **gym-bound only** (SPEC §5.3). Switching re-scopes the
    /// screen and re-derives the whole curve, because a gym-bound exercise's rep-maxes
    /// come from one machine's entries and nothing else.
    ///
    /// It is the app's one machine picker, the same rows the log sheet's caption opens
    /// (§6.4). Creating a machine is not offered here: this menu resolves between
    /// machines that exist, and the hole it cannot close belongs where you are standing
    /// at the rack — inside the sheet.
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

    /// The two rows under the curve (SPEC §5.1). `Entries at N+ reps M ›` opens §5.6's
    /// sheet, and has no `›` and no sheet on an unproven cell; `Logged K entries` counts
    /// every entry in scope.
    private func rows(_ readout: ExerciseDetailModel.Readout) -> some View {
        VStack(spacing: 0) {
            FactRow(
                label: "Entries at \(readout.reps)+ reps",
                value: "\(readout.entriesBehind)",
                action: readout.weight == nil ? nil : { history = model.historySheet() }
            )
            FactRow(
                label: "Logged",
                value: readout.entriesInScope == 1 ? "1 entry" : "\(readout.entriesInScope) entries"
            )
        }
    }

    /// The goal, one line under the number — or under the empty state's text
    /// — and **never on the chart** (#74). Tapping it opens the goal sheet: the thing you
    /// are looking at is also the door to changing it.
    @ViewBuilder
    private var goalLine: some View {
        if let line = model.goalLine {
            GoalLineView(line: line)
                .onTapGesture { goalSheet = model.goalSheet() }
        }
    }

    /// The brief confirmation the screen flashes after a save, while the curve behind
    /// it has already moved (SPEC §6.7). It says the entry landed and then gets out of
    /// the way — there is nothing to undo here and nothing to tap.
    @ViewBuilder
    private var confirmation: some View {
        if flashingConfirmation {
            Label("Logged", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
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
    /// implies numbers that do not exist.
    ///
    /// **The empty state carries the machine hint**: one dimmed line quoting your numbers
    /// on the sibling machine, and **text rather than a dimmed curve** — a shape on the
    /// chart that is not yours is exactly what the never-mistakable-for-a-record rule
    /// forbids. A free-weight exercise, and a gym-bound one with no usable sibling, get
    /// bare text.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing logged yet.")
                .font(.title3.weight(.semibold))
            Text(emptyDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let hint = model.hint {
                Text(hint.emptyStateLine)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            // After the prompt to go and log, never ahead of it.
            goalLine
                .padding(.top, 6)
        }
        .padding(.top, 16)
    }

    /// A gym-bound exercise with no machine yet keeps its numbers per machine and has
    /// none, so the line says so — and the Log bar still opens, because the row that
    /// makes the first machine lives in the sheet's own picker (SPEC §6.4).
    private var emptyDetail: String {
        model.needsFirstMachine
            ? "Its numbers are kept per machine. Log a lift and name the one you are at."
            : "Log a lift and your curve starts here."
    }

    /// Full width, pinned at the bottom. Opens the log sheet (SPEC §6.1), handing it the
    /// qualifier's own machine — **the sheet never resolves one itself** (§6.4).
    ///
    /// **Never disabled**, gym-bound exercise with no machine included: that is the one
    /// case this caller cannot answer, and the sheet's own picker is where it is answered
    /// rather than a bar that will not open.
    private var logBar: some View {
        Button {
            logging = true
        } label: {
            Text("Log")
                .font(.headline)
                .foregroundStyle(Color.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
