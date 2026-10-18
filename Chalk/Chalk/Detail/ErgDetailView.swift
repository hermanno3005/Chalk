import SwiftUI

/// The erg detail screen (SPEC §13.8), laid out like §5's: zone buttons and the incline
/// menu, the scrub readout, the 150 pt zone line and its over-20:00 caption, empty space,
/// and the Log bar into the lap-list sheet (§13.7). The machine qualifier sits in the
/// toolbar on a gym-bound erg, beside an overflow of the erg's lifetime operations.
/// Zones not set swap the zone buttons, readout and line for a row into Settings.
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
    /// The gym the qualifier's `New machine here` is naming a machine at.
    @State private var naming: Gym?

    @State private var settings: SettingsModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.isEmpty {
                empty
            } else if !model.needsZones, let selection = model.selection {
                zoneBar(selection)
                if let readout = model.readout {
                    // The `›` is inert until the point's sheet exists (SPEC §13.9).
                    readoutView(readout)
                }
                if let points = model.reading.line?.points, !points.isEmpty {
                    ZoneLineChart(
                        points: points,
                        unit: model.unit ?? .speed,
                        selectedDuration: selection.duration,
                        onSelect: model.select(duration:)
                    )
                }
                if let caption = model.overTheAxisCaption {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            // Zones not set: one row in place of the buttons, readout and line — under
            // the empty text too, so a first erg says what it will need.
            if model.needsZones {
                zonesRow
            }
            Spacer(minLength: 0)
        }
        .animation(.snappy, value: model.selection)
        .padding(.horizontal)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { logBar }
        .sheet(item: $logging) { LapListSheet(model: $0) }
        // Entries logged before the zones join the lines the moment they are set.
        .sheet(item: $settings, onDismiss: model.refresh) { SettingsSheet(model: $0) }
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

    /// §5.4: nothing logged on the scope — no chart, no axes, no readout, short text.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing logged yet.")
                .font(.title3.weight(.medium))
            Text("Log a block and what you held in each zone starts here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    /// Opens Settings, which is where zones are set (SPEC §13.3).
    private var zonesRow: some View {
        Button {
            settings = model.settings()
        } label: {
            HStack {
                Label("Set your heart-rate zones", systemImage: "heart")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// `Z1`–`Z5`, with the incline menu at the trailing end on a speed erg. **A zone with
    /// no line here is dimmed but still tappable.**
    private func zoneBar(_ selection: ErgReading.Selection) -> some View {
        HStack(spacing: 6) {
            ForEach(ZoneLine.zones, id: \.self) { zone in
                let isSelected = zone == selection.zone
                let hasLine = model.hasLine(zone)
                Button {
                    model.select(zone: zone)
                } label: {
                    Text("Z\(zone)")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 40, height: 32)
                        .foregroundStyle(
                            isSelected ? Color.white : hasLine ? Color.primary : Color.secondary.opacity(0.5)
                        )
                        .background(
                            isSelected ? Color.accentColor : Color.secondary.opacity(hasLine ? 0.14 : 0.05),
                            in: .rect(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer(minLength: 0)
            if model.unit == .speed {
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
            Label("\(EnduranceText.incline(selection.incline)) %", systemImage: "arrow.up.right")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12), in: .capsule)
        }
        .accessibilityLabel("Incline \(EnduranceText.incline(selection.incline)) percent")
    }

    /// One large intensity, a speed's pace under it, then the point's duration, zone,
    /// mean heart rate and entry count. No ± band: the count is the uncertainty.
    private func readoutView(_ readout: ErgReading.Readout) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(readout.intensity)
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            if let pace = readout.pace {
                Text(pace)
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Text(readout.detail)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
