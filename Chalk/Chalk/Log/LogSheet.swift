import SwiftUI

/// The log sheet (SPEC §6.1–6.3, §6.5, §6.7): reps, then weight, **one giant number on
/// screen at a time**. The size and the staging are the point — a single unmissable
/// digit and two thumb-sized targets is what survives sweaty hands.
///
/// **The same sheet is the edit sheet** (SPEC §6.6): opened from a history row it seeds
/// from that entry and writes back in place, differing only in the date it states and
/// will not let you change.
///
/// **The machine caption sits above the number, on both stages and gym-bound only**
/// (§6.4): one quiet tappable line reading `Hammer Strength · Fitness X`. It is never
/// hidden "unless something is odd" — a strip that comes and goes shifts the layout and
/// stops being trusted — and a free-weight sheet carries no machine row at all. The
/// fifth verdict state is the machine hint (§6.5).
struct LogSheet: View {
    /// Held in `@State` for the life of the presentation, as the detail screen holds
    /// its own model: the sheet's content is rebuilt as the screen behind it changes,
    /// and every model past the first is dropped. Dismissing tears it down, so the next
    /// presentation seeds afresh from your most recent entry.
    @State var model: LogSheetModel

    @Environment(\.dismiss) private var dismiss
    /// The gym `New machine here` was tapped in, held while its one-field alert is up.
    /// **Always asked** — you cannot know at creation time whether a second machine is
    /// coming (SPEC §6.4).
    @State private var naming: Gym?
    @State private var draftMachineName = ""
    @State private var creatingGym = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                caption
                number
                verdict
                Spacer(minLength: 0)
                input
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .navigationTitle(model.exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Dismisses without writing (SPEC §6.1).
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    switch model.stage {
                    case .reps:
                        Button("Next") { withAnimation(.snappy) { model.advance() } }
                            .disabled(!model.canAdvance)
                    case .weight:
                        Button("Save") {
                            model.save()
                            // Never stays open to log again: sessions are not modelled
                            // (SPEC §6.7).
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(!model.canSave)
                    }
                }
            }
            // One field, optional, with Skip — the machine is created at the gym its
            // row sat in and **the sheet resolves to it**, so there is no second
            // decision (SPEC §6.4).
            .alert("Name this machine", isPresented: namingIsPresented, presenting: naming) { gym in
                TextField("Optional", text: $draftMachineName)
                Button("Add") { model.createMachine(at: gym, named: draftMachineName) }
                Button("Skip") { model.createMachine(at: gym, named: nil) }
            } message: { _ in
                Text("Optional — you can leave it unnamed.")
            }
            // `New gym…`: standing in an unfamiliar gym is exactly when you need one.
            // The gym alone, though — the machine you are at is `New machine here`'s
            // always-asked decision, and the new gym's section is where you make it.
            .sheet(isPresented: $creatingGym) {
                NewGymSheet(gyms: model.gyms, onCreate: model.gymCreated)
            }
        }
    }

    private var namingIsPresented: Binding<Bool> {
        Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })
    }

    /// **The machine, on both stages** (SPEC §6.4). It reads as a caption, not a
    /// control — the number below stays the only thing on screen with weight — and
    /// tapping it opens **the app's one machine picker** (§5.3), plus the two rows only
    /// this sheet needs: `New machine here` in each gym section, and `New gym…` at the
    /// bottom.
    ///
    /// Absent altogether for a free-weight exercise, which has no machine to carry.
    @ViewBuilder
    private var caption: some View {
        if let machineCaption = model.machineCaption {
            Menu {
                MachinePicker(
                    menu: model.machineMenu,
                    selected: model.machine,
                    onSelect: model.select,
                    onNewMachine: { gym in
                        draftMachineName = ""
                        naming = gym
                    },
                    onNewGym: { creatingGym = true }
                )
            } label: {
                Label(machineCaption, systemImage: "square.stack.3d.up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.vertical, 8)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Changes the machine this is logged on")
        }
    }

    /// The stage-two header: **the earlier answer, always visible and correctable
    /// without cancelling** (SPEC §6.1). Its row keeps its height on stage one so the
    /// number does not jump as the stages change.
    private var header: some View {
        HStack {
            if model.stage == .weight {
                Button {
                    withAnimation(.snappy) { model.backToReps() }
                } label: {
                    Label(model.repsLabel, systemImage: "chevron.left")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            Spacer(minLength: 0)
            // An edit says which lift it is correcting. The date is not editable
            // (SPEC §6.6), so it is stated rather than offered.
            if let dateLabel = model.dateLabel {
                Text(dateLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 44)
    }

    /// The one thing on screen with weight. **Tapping it swaps the steppers for the
    /// keypad** and back (SPEC §6.2); the digits move rather than cross-fading, which
    /// is what makes staging read as progress rather than a detour (§6.1).
    private var number: some View {
        Button {
            withAnimation(.snappy) { model.tapNumber() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.numberText)
                    .font(.system(size: 92, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: model.numberText)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(model.unitText)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model.numberText.isEmpty ? "Blank" : model.numberText) \(model.unitText)")
        .accessibilityHint(model.mode == .keypad ? "Shows the steppers" : "Types a number")
    }

    /// **Weight stage only** (SPEC §6.5). The space is reserved on both stages: a line
    /// that comes and goes shifts the number above it.
    ///
    /// **The hint is drawn softer than a real verdict** — secondary against the verdict's
    /// own colour, so a number lifted on another machine never reads as one of yours
    /// here. Zero new layout: it is a fifth state of the line that already reserves this
    /// space.
    private var verdict: some View {
        Text(model.verdict?.text ?? " ")
            .font(.subheadline)
            .foregroundStyle(model.verdict?.isHint == true ? Color.secondary : .primary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 22)
            .animation(.snappy(duration: 0.2), value: model.verdict)
    }

    @ViewBuilder
    private var input: some View {
        switch model.mode {
        case .steppers: steppers
        case .keypad: LogKeypad(decimalIsDead: model.stage == .reps, onKey: model.type)
        }
    }

    /// **±1 rep, ±2.5 kg**, and on weight the step snaps to the grid rather than adding
    /// (SPEC §6.2). Tap only — no hold-to-repeat and no acceleration, so these are plain
    /// buttons and nothing here recognises a long press.
    private var steppers: some View {
        HStack(spacing: 16) {
            stepper(-1, symbol: "minus")
            stepper(+1, symbol: "plus")
        }
    }

    private func stepper(_ direction: Int, symbol: String) -> some View {
        Button {
            withAnimation(.snappy) { model.step(direction) }
        } label: {
            Image(systemName: symbol)
                .font(.title.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 88)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .accessibilityLabel(stepperLabel(direction))
    }

    private func stepperLabel(_ direction: Int) -> String {
        let up = direction > 0
        switch model.stage {
        case .reps: return up ? "One rep more" : "One rep fewer"
        case .weight: return up ? "Up to the next 2.5 kilograms" : "Down to the next 2.5 kilograms"
        }
    }
}
