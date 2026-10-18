import SwiftUI

/// An erg's history sheet (SPEC §13.9): the point's entries from all time with the
/// window's divider, or the flat over-20:00 list. **Tap a row to edit it, swipe left to
/// delete it** — full-swipe off, as §5.6's.
///
/// Unlike §5.6's sheet, **an emptied point leaves this sheet open and empty**: the screen
/// behind it settles on its own, and the sheet goes when you close it.
struct ErgHistorySheet: View {
    /// Held for the life of the presentation, as `HistorySheet` holds its model.
    @State var model: ErgHistoryModel

    @Environment(\.dismiss) private var dismiss
    @State private var editing: LapListModel?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.rows) { row($0) }
                }
                if !model.older.isEmpty {
                    Section {
                        ForEach(model.older) { row($0) }
                    } header: {
                        Text(ErgHistoryModel.divider)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if model.isEmpty {
                    ContentUnavailableView("No entries left", systemImage: "tray")
                }
            }
            .navigationTitle(model.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editing) { LapListSheet(model: $0) }
        }
    }

    private func row(_ row: ErgHistoryModel.Row) -> some View {
        Row(row: row)
            .contentShape(.rect)
            // The lap-list grid over this one entry (SPEC §13.9). A tap gesture rather
            // than a `Button`, which would swallow the swipe.
            .onTapGesture { editing = model.editSheet(for: row) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // No confirmation and no undo, exactly §5.6.
                Button("Delete", systemImage: "trash", role: .destructive) {
                    withAnimation(.snappy) { model.delete(row) }
                }
            }
    }

    /// `date · intensity (pace beside a speed) · avg/peak bpm`, in the spec's order, with
    /// the duration after the date on the over-20:00 list. Nothing is flagged.
    private struct Row: View {
        let row: ErgHistoryModel.Row

        var body: some View {
            Text(row.text)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHint("Edits this entry")
        }
    }
}
