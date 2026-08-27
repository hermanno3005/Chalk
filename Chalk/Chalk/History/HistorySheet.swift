import SwiftUI

/// The `reps >= N` history sheet (SPEC §5.6). The only entry point to raw history, and
/// the only place an entry can be edited or deleted.
///
/// A plain list, newest first: the numbers lead each row, the day sits at its end, and
/// the entry currently setting the cell carries a flag. **Tap a row to edit it, swipe
/// left to delete it** — and the swipe never goes all the way, so deleting always takes
/// two deliberate gestures.
struct HistorySheet: View {
    /// Held for the life of the presentation, as the other sheets hold theirs: the
    /// content is rebuilt as the detail screen behind it re-derives, and every model
    /// past the first is dropped.
    @State var model: HistorySheetModel

    @Environment(\.dismiss) private var dismiss
    @State private var editing: LogSheetModel?
    @State private var flashingConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.rows) { row in
                    Row(row: row)
                        .contentShape(.rect)
                        // Tapping opens the same log sheet, seeded from this entry
                        // (SPEC §6.6). A plain tap gesture rather than a `Button`,
                        // which would swallow the row's swipe.
                        .onTapGesture {
                            editing = model.editSheet(for: row) { flashConfirmation() }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // No confirmation and no undo (SPEC §5.6). The cost is
                            // bounded: you just read the numbers, and re-logging is
                            // two taps.
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                withAnimation(.snappy) { model.delete(row) }
                            }
                        }
                }
            }
            .listStyle(.plain)
            .navigationTitle(model.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editing) { LogSheet(model: $0) }
            .overlay(alignment: .bottom) { confirmation }
        }
        // The sheet is only ever reachable from a cell that exists, so when the last
        // row leaves — deleted, or edited below the threshold — there is nothing left
        // to explain and the sheet goes with it.
        .onChange(of: model.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    /// The brief confirmation §6.7 asks for, flashed **here** rather than on the detail
    /// screen: an edit is saved with this list in view and the curve two layers down,
    /// and the list behind the flash has already moved.
    @ViewBuilder
    private var confirmation: some View {
        if flashingConfirmation {
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: .capsule)
                .padding(.bottom, 24)
                .transition(.opacity)
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

    /// One line of history: `8 × 62.5 kg` and the day, with the flag on the entry
    /// setting the cell this sheet was opened from.
    private struct Row: View {
        let row: HistorySheetModel.Row

        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                numbers
                // The machine, where the exercise is gym-bound (SPEC §5.6). The list is
                // already scoped to one, so this is the scope said out loud rather than
                // a way to tell the rows apart — and it is what an edit that moves an
                // entry to another machine (#28) changes under you.
                if let machine = row.machine {
                    Text(machine)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Edits this entry")
        }

        private var numbers: some View {
            HStack(spacing: 8) {
                Text(row.lift)
                    .font(.body.weight(row.isBest ? .semibold : .regular))
                    .monospacedDigit()
                if row.isBest {
                    Text("best")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: .capsule)
                }
                Spacer(minLength: 8)
                Text(row.day)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }

        private var accessibilityLabel: String {
            [
                row.lift,
                row.day,
                row.machine,
                row.isBest ? "sets this best" : nil,
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
        }
    }
}
