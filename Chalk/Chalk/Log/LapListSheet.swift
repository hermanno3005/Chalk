import SwiftUI

/// The endurance log sheet (SPEC §13.7): **a grid shaped like the watch's lap list**,
/// one row per entry, columns in the watch's order, and one keypad always up beneath it.
///
/// The grid scrolls once a block outgrows its space; the line under it, the focus header
/// and the keypad never move. Everything it shows and does is `LapListModel`'s.
struct LapListSheet: View {
    /// Held in `@State` for the life of the presentation, as `LogSheet`'s model is.
    @State var model: LapListModel

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDiscard = false
    /// The gym `New machine here` was tapped in, held while its one-field alert is up —
    /// always asked, as strength's is (SPEC §6.4).
    @State private var naming: Gym?
    @State private var creatingGym = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // **Once, above the grid, covering every row** — a block is logged on
                // one machine (SPEC §13.7). Absent on a transferable erg.
                if let machineCaption = model.machineCaption {
                    MachineCaptionMenu(
                        text: machineCaption,
                        menu: model.machineMenu,
                        selected: model.machine,
                        onSelect: model.select,
                        onNewMachine: { naming = $0 },
                        onNewGym: { creatingGym = true }
                    )
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        grid
                        // An edit is one entry: no new row (SPEC §13.9).
                        if model.canAddRows {
                            Button {
                                withAnimation(.snappy) { model.addRow() }
                            } label: {
                                Label("Add an entry", systemImage: "plus")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity, minHeight: 40)
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 6)
                            .id(Self.addRowID)
                        }
                    }
                    .onChange(of: model.rows.count) { proxy.scrollTo(Self.addRowID) }
                }
                line
                    .padding(.vertical, 8)
                header
                    .padding(.bottom, 8)
                NumberKeypad(decimalIsDead: model.decimalIsDead) { key in
                    withAnimation(.snappy(duration: 0.15)) { model.type(key) }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            // The erg while logging; the entry's date, not editable, on an edit.
            .navigationTitle(model.title)
            .navigationBarTitleDisplayMode(.inline)
            // A stray swipe must not lose a block once anything is typed.
            .interactiveDismissDisabled(model.isTouched)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // An untouched sheet closes without asking.
                        if model.isTouched { confirmingDiscard = true } else { dismiss() }
                    }
                    .confirmationDialog(
                        model.discardConfirmation,
                        isPresented: $confirmingDiscard,
                        titleVisibility: .visible
                    ) {
                        Button(discardTitle, role: .destructive) {
                            dismiss()
                        }
                        Button("Keep Typing", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.saveTitle) {
                        model.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!model.canSave)
                }
            }
            .namingMachine(at: $naming, check: { model.nearModel(named: $1, at: $0) }) { gym, name in
                model.createMachine(at: gym, named: name)
            }
            .sheet(isPresented: $creatingGym) {
                NewGymSheet(gyms: model.gyms, onCreate: model.gymCreated)
            }
        }
    }

    private static let addRowID = "add-row"

    private var discardTitle: String {
        if !model.canAddRows { return "Discard Changes" }
        return model.rows.count == 1 ? "Discard Entry" : "Discard \(model.rows.count) Entries"
    }

    private var grid: some View {
        Grid(horizontalSpacing: 5, verticalSpacing: 6) {
            GridRow {
                ForEach(model.columns, id: \.self) { field in
                    Text(field.columnTitle(model.unit, model.distanceUnit))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Color.clear.frame(width: 34, height: 1)
            }
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, _ in
                GridRow {
                    ForEach(model.columns, id: \.self) { field in
                        cell(.init(row: index, field: field))
                    }
                    deleteButton(index)
                }
            }
        }
    }

    private func cell(_ cell: LapListModel.Cell) -> some View {
        let focused = model.focus == cell
        let text = model.text(cell)
        return Button {
            withAnimation(.snappy(duration: 0.15)) { model.select(cell) }
        } label: {
            Text(text.isEmpty ? "–" : text)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(focused ? Color.accentColor.opacity(0.2) : Color(.secondarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(
                            model.isFlagged(cell) ? Color.red : focused ? Color.accentColor : .clear,
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Row \(cell.row + 1), \(cell.field.name(model.unit))")
        .accessibilityValue(text.isEmpty ? "Blank" : text)
    }

    /// A row added one too many is deleted from the row itself. The last remaining row
    /// has none — Cancel is how you log nothing.
    @ViewBuilder
    private func deleteButton(_ index: Int) -> some View {
        if model.canDeleteRows {
            Button {
                withAnimation(.snappy) { model.deleteRow(index) }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
                    .frame(width: 34, height: 46)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete row \(index + 1)")
        } else {
            Color.clear.frame(width: 34, height: 46)
        }
    }

    /// The focused row's zone, or why it cannot be saved. The space is held whether or
    /// not anything shows, so nothing above it moves.
    private var line: some View {
        Group {
            switch model.line {
            case .problem(let text):
                Label(text, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            case .zone(let text):
                Text(text).foregroundStyle(.secondary)
            case nil:
                Text(" ")
            }
        }
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 22)
    }

    private var header: some View {
        HStack {
            Text(model.focusTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                withAnimation(.snappy(duration: 0.15)) { model.next() }
            } label: {
                Label(
                    model.nextIsNewRow ? "New row" : "Next",
                    systemImage: model.nextIsNewRow ? "return" : "arrow.right"
                )
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
    }
}
