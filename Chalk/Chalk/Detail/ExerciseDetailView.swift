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
    /// `Change kind` in flight: the confirmation for the flip that needs no machine,
    /// and the prompt for the one that does (SPEC §8).
    @State private var confirmingKindChange = false
    @State private var changingKind = false
    @State private var logging = false
    @State private var history: HistorySheetModel?
    @State private var goalSheet: GoalSheetModel?
    @State private var flashingConfirmation = false
    /// PROTOTYPE (#141): the exercise's bar, 0 for none. Held outside the model, which has
    /// no `bar` yet.
    @AppStorage("prototype.bar") private var protoBar = 20.0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.hasCurve, Palette.current.style == .layout, let readout = model.readout {
                tradeRepublicLayout(readout)
            } else if model.hasCurve {
                if let readout = model.readout {
                    // The one way into raw history (SPEC §5.6). A plain tap on the
                    // readout, not a `Button`: the number keeps its own colour, and
                    // nothing on this screen should look tappable twice over. An
                    // unproven cell hands back no sheet, and shows no chevron.
                    VStack(alignment: .leading, spacing: 6) {
                        ScrubReadout(readout: readout)
                            .contentShape(.rect)
                            .onTapGesture { history = model.historySheet() }
                        goalLine
                    }
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
        .tradeRepublicText()
        // PROTOTYPE (#140): E says the name above the number instead.
        .navigationTitle(Palette.current.style == .layout ? "" : model.name)
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
                    if Palette.current.style == .layout, !model.isGymBound { barMenu }
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

    /// PROTOTYPE (#140), E: Trade Republic's stock screen. The name in grey, the number
    /// with the rep count beside it as their `▲ 10,55 %`, the goal, the chart bled off the
    /// leading edge, and what the subhead said moved into a row under it.
    private func tradeRepublicLayout(_ readout: ExerciseDetailModel.Readout) -> some View {
        // PROTOTYPE (#141): the plate breakdown, in the variant the root's bar picks.
        let unit = PlateProto.unit
        let breakdown = protoBar > 0 ? readout.weight.map {
            PlateBreakdown(weight: $0, bar: protoBar, unit: unit)
        } : nil
        let variant = PlateProto.variant
        return VStack(alignment: .leading, spacing: 0) {
            NamedNumber(
                name: model.name,
                number: readout.weight.map { "\($0.kilogramsText) \(unit.rawValue)" } ?? "—",
                aside: "× \(readout.reps)",
                dimmed: readout.weight == nil
            )
            .contentShape(.rect)
            .onTapGesture { history = model.historySheet() }
            if variant == .line, let breakdown {
                PlateLine(breakdown: breakdown, unit: unit, bar: protoBar)
                    .padding(.top, 4)
            }
            goalLine
                .padding(.top, 12)
            if variant == .sleeve, let breakdown {
                PlateSleeve(breakdown: breakdown, unit: unit, bar: protoBar)
                    .padding(.top, 16)
            }
            StrengthCurve(
                curve: model.curve,
                selectedReps: model.selectedReps,
                onSelect: model.select
            )
            .padding(.leading, -16)
            .padding(.top, variant == .sleeve && breakdown != nil ? 16 : 40)
            if variant == .row, let breakdown {
                PlateRow(breakdown: breakdown, unit: unit, bar: protoBar)
                    .padding(.top, 28)
            }
            FactRow(
                label: "Entries at \(readout.reps)+ reps",
                value: "\(readout.entriesBehind)",
                opens: readout.weight != nil,
                action: readout.weight == nil ? nil : { history = model.historySheet() }
            )
            .padding(.top, variant == .row && breakdown != nil ? 0 : 28)
            FactRow(label: "Logged", value: "\(model.entryCount) entries")
        }
    }

    /// PROTOTYPE (#141): the bar, in the overflow. *No bar*, the weight unit's presets, and
    /// a typed weight, which the prototype shows but does not ask for.
    private var barMenu: some View {
        let unit = PlateProto.unit
        return Menu {
            Picker("Bar", selection: $protoBar) {
                Text("No bar").tag(0.0)
                ForEach(unit.barPresets, id: \.self) { preset in
                    Text("\(preset.plateText) \(unit.rawValue)").tag(preset)
                }
                if protoBar > 0, !unit.barPresets.contains(protoBar) {
                    Text("\(protoBar.plateText) \(unit.rawValue)").tag(protoBar)
                }
            }
            Button("Other weight…") {}
        } label: {
            Label(
                protoBar > 0 ? "Bar · \(protoBar.plateText) \(unit.rawValue)" : "Bar",
                systemImage: "minus"
            )
        }
    }

    /// The goal, one line under the readout's subhead — or under the empty state's text
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
                .font(.title3.weight(.medium))
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
        .padding(.top, 8)
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
                .foregroundStyle(Palette.current.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
