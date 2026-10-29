import SwiftUI

/// The erg detail screen (SPEC §13.8), laid out like §5's as Trade Republic's stock
/// screen (§15.4): the name in grey over the intensity and `6:00 in Z4`, the goal line,
/// the zone tabs and the incline menu, the zone line and its over-20:00 caption, the
/// rows, empty space, and the Log bar into the lap-list sheet (§13.7). The machine
/// qualifier sits in the toolbar on a gym-bound erg, beside an overflow of the erg's
/// lifetime operations. Zones not set swap the tabs, readout and line for a row into
/// Settings.
struct ErgDetailView: View {
    /// Held in `@State` for the life of the push, as `ExerciseDetailView`'s model is.
    @State var model: ErgDetailModel

    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var draftName = ""
    @State private var changingUnit = false
    @State private var changingKind = false
    @State private var confirmingDelete = false
    @State private var logging: LapListModel?
    /// The point's sheet or the over-20:00 list (SPEC §13.9).
    @State private var history: ErgHistoryModel?
    /// The gym the qualifier's `New machine here` is naming a machine at.
    @State private var naming: Gym?

    @State private var settings: SettingsModel?
    @State private var goalSheet: EnduranceGoalSheetModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isEmpty {
                DetailHead(name: model.name)
                empty
                goalLine
                    .padding(.top, 12)
            } else if !model.needsZones, let selection = model.selection {
                // A zone with no line keeps the number's place with a dimmed `—`, so
                // the tabs stay under your thumb as you move between zones.
                DetailHead(
                    name: model.name,
                    number: model.readout?.intensity ?? "—",
                    aside: model.readout?.aside,
                    dimmed: model.readout == nil,
                    // The readout opens the point's sheet, as the `Entries` row does
                    // (SPEC §13.9). A zone with no line hands back no sheet.
                    opensHistory: model.readout != nil
                )
                .onTapGesture { history = model.historySheet() }
                // Under the number, whatever zone is selected: it is the goal's point,
                // not the screen's (SPEC §13.10).
                goalLine
                    .padding(.top, 12)
                tabs(selection)
                    .padding(.top, 24)
                if let readout = model.readout, let points = model.reading.line?.points, !points.isEmpty {
                    ZoneLineChart(
                        points: points,
                        unit: model.unit ?? .speed,
                        selectedDuration: selection.duration,
                        onSelect: model.select(duration:)
                    )
                    .detailChart()
                    .padding(.top, 16)
                    overTheAxisCaption
                    rows(readout)
                        .padding(.top, 16)
                } else if let noLine = model.noLine {
                    ErgNoLineView(noLine: noLine)
                        .padding(.top, 16)
                    overTheAxisCaption
                }
            } else {
                DetailHead(name: model.name)
            }
            // Zones not set: one row in place of the tabs, readout and line — under
            // the empty text too, so a first erg says what it will need.
            if model.needsZones {
                zonesRow
                    .padding(.top, 16)
            }
            Spacer(minLength: 0)
        }
        .animation(.snappy, value: model.selection)
        .padding(.horizontal)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chalkScreen()
        // The name is the readout's (SPEC §13.8); kept as the title for the back menu
        // and VoiceOver, never drawn in the bar.
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .safeAreaInset(edge: .bottom) { logBar }
        .sheet(item: $logging) { LapListSheet(model: $0) }
        .sheet(item: $history) { ErgHistorySheet(model: $0) }
        // Entries logged before the zones join the lines the moment they are set, and a
        // relabel or a convert there moves the scale this screen and the grid behind it write in.
        .sheet(item: $settings, onDismiss: model.settingsClosed) { SettingsSheet(model: $0) }
        .sheet(item: $goalSheet) { EnduranceGoalSheet(model: $0) }
        // A unit change says so when it clears a goal (SPEC §13.6).
        .alert(
            "Goal cleared",
            isPresented: Binding(
                get: { model.clearedGoalNotice != nil },
                set: { if !$0 { model.clearedGoalNotice = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.clearedGoalNotice ?? "")
        }
        // The qualifier's `New machine here` (SPEC §13.11), on the screen rather than the
        // toolbar item so it outlives the menu that raised it.
        .namingMachine(at: $naming, check: { model.nearModel(named: $1, at: $0) }) { gym, name in
            model.createMachine(at: gym, named: name)
        }
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
                    // Absent until zones are set, and on a gym-bound erg with no machine
                    // (SPEC §13.10).
                    if let goalMenuLabel = model.goalMenuLabel {
                        Button(goalMenuLabel, systemImage: "scope") { goalSheet = model.goalSheet() }
                    }
                    // **Absent, not disabled**, once the erg has an entry (SPEC §13.6).
                    if model.canChangeUnit {
                        Button("Change unit…", systemImage: "ruler") { changingUnit = true }
                    }
                    // Transferable ↔ gym-bound (SPEC §13.11); `ErgChangeKind` asks the rest.
                    Button("Change kind", systemImage: "arrow.left.arrow.right") { changingKind = true }
                    Button("Delete erg", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .changingKind(of: model, isRequested: $changingKind)
        .alert("Rename", isPresented: $renaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { model.rename(to: draftName) }
        }
        .confirmationDialog("Change unit", isPresented: $changingUnit, titleVisibility: .visible) {
            ForEach(ErgUnit.allCases.filter { $0 != model.unit }, id: \.self) { unit in
                Button(unit.pickerTitle(model.distanceUnit)) { model.changeUnit(to: unit) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Now \(model.unit?.pickerTitle(model.distanceUnit) ?? "none"). The unit locks once you log on this erg.")
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

    /// The machine qualifier — **gym-bound only**, as on a gym-bound exercise (SPEC §5.3,
    /// §13.8): the app's one machine picker, switching which machine the screen and its
    /// Log bar are scoped to — plus `New machine here` in each gym section (§13.11),
    /// checked against this erg's models as the log sheet's caption is.
    private var qualifier: some View {
        Menu {
            MachinePicker(
                menu: model.machineMenu,
                selected: model.machine,
                onSelect: model.select,
                onNewMachine: { naming = $0 }
            )
        } label: {
            // An erg with no machine yet says so rather than staying blank.
            Label(model.machine?.name ?? MachineCaption.noMachine, systemImage: "square.stack.3d.up")
        }
        // Nothing to pick and nowhere to make one: no gym is current and none holds a
        // machine for this erg.
        .disabled(model.machineMenu.isEmpty)
    }

    /// §5.4: nothing logged on the scope — no chart, no axes, no readout, short text, and
    /// on a gym-bound erg's new machine the hint under it.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing logged yet.")
                .font(.title3.weight(.semibold))
            Text("Log a block and what you held in each zone starts here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // Another machine's numbers, as text and dimmed: never part of any line.
            if let hint = model.hint {
                Text(hint.emptyStateLine)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 16)
    }

    /// The goal line — no `›`, never on the chart — opening the goal sheet (SPEC §13.10).
    @ViewBuilder
    private var goalLine: some View {
        if let line = model.goalLine {
            ErgGoalLine(line: line) { goalSheet = model.goalSheet() }
        }
    }

    /// Opens Settings, which is where zones are set (SPEC §13.3): a row like the ones
    /// under the line, with nothing to read on its trailing end.
    private var zonesRow: some View {
        FactRow(label: "Set your heart-rate zones", value: "") {
            settings = model.settings()
        }
    }

    /// The zones as text tabs, with the incline menu at the trailing end on a speed erg.
    private func tabs(_ selection: ErgReading.Selection) -> some View {
        HStack(spacing: 0) {
            ZoneTabs(selected: selection.zone, hasLine: model.hasLine, onSelect: model.select(zone:))
            Spacer(minLength: 0)
            if model.unit?.hasIncline == true {
                inclineMenu(selection)
            }
        }
    }

    private func inclineMenu(_ selection: ErgReading.Selection) -> some View {
        Menu {
            Picker("Incline", selection: Binding(
                get: { selection.incline },
                set: { model.select(incline: $0) }
            )) {
                ForEach(model.inclines, id: \.self) { incline in
                    Text("\(EnduranceText.incline(incline)) %").tag(incline)
                }
            }
        } label: {
            // Text, as the tabs beside it are: no fill.
            HStack(spacing: 4) {
                Text("\(EnduranceText.incline(selection.incline)) %")
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
            }
            .font(.callout)
            .foregroundStyle(.primary)
            .frame(height: 32)
        }
        .accessibilityLabel("Incline \(EnduranceText.incline(selection.incline)) percent")
    }

    /// The dimmed `2 entries over 20:00 ›` caption under the line, or under the no-line
    /// text: a door to the flat over-20:00 list (SPEC §13.9).
    @ViewBuilder
    private var overTheAxisCaption: some View {
        if let caption = model.overTheAxisCaption {
            Button {
                history = model.overTheAxisSheet()
            } label: {
                Text("\(caption) ›")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    /// The rest of the readout under the line (SPEC §13.8): `Pace` on a speed erg, the
    /// point's mean `Heart rate`, and `Entries N ›`, **the chart's only door** to the
    /// point's entries (§13.9) — tapping a point does nothing; scrubbing only selects.
    /// No ± band: the count is the uncertainty.
    private func rows(_ readout: ErgReading.Readout) -> some View {
        VStack(spacing: 0) {
            if let pace = readout.pace {
                FactRow(label: "Pace", value: pace)
            }
            FactRow(label: "Heart rate", value: readout.averageHeartRate)
            FactRow(label: "Entries", value: "\(readout.entryCount)") {
                history = model.historySheet()
            }
        }
    }

    private var logBar: some View {
        Button {
            logging = model.logSheet()
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
