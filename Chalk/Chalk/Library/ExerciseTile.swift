import SwiftUI

/// One exercise in the grid: its name, and what you last did for it (SPEC §7.1). In
/// **Arrange mode** it also carries the `•••` group picker that files it (SPEC §7.2).
///
/// **A plain view with a tap gesture, not a `Button`** — SPEC §7.2's second hazard: a
/// button's own gesture claims the press, so `.draggable` on it rarely fires. For the same
/// reason it carries no `.contextMenu` — hazard one: both are long-press driven and the
/// menu wins every time, which is what stopped the drag from ever starting in the
/// prototype. The picker is a `Menu` on a small button of its own, which is a tap rather
/// than a press and so fights nothing.
struct ExerciseTile: View {
    let tile: LibraryTile
    /// Whether the library is in Arrange mode. A mode, so it changes what the tile *is*:
    /// the picker appears, and a tap no longer opens the exercise — you are filing, not
    /// navigating, and opening a screen mid-arrange is never what the tap meant.
    var arranging = false
    /// The groups the picker offers, in the user's own order. Empty groups included:
    /// the grid leaves those out, and the picker is the only way back into one.
    var groups: [ExerciseGroup] = []
    let onOpen: () -> Void
    var onAssign: (ExerciseGroup?) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                Text(tile.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                if arranging {
                    Spacer(minLength: 0)
                    picker
                }
            }

            // An exercise with nothing logged says nothing — a placeholder line here
            // would be a number that does not exist (SPEC §4).
            if let lastEntry = tile.lastEntry {
                Text(lastEntry.text())
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { if !arranging { onOpen() } }
        // The fast path, and only ever the fast path: dragging the length of a 42-tile
        // scroll to reach Ungrouped is not pleasant however well the gesture works, which
        // is why `picker` exists and why nothing depends on this landing.
        .draggable(DraggedExercise(id: tile.id)) {
            Text(tile.name)
                .font(.subheadline.weight(.medium))
                .padding(10)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// **The path that always works.** A plain menu, no gesture at all: tap, pick a
    /// group, done — and Ungrouped is the first item rather than the last, because
    /// filing something back out of a group is the move the drag is worst at.
    private var picker: some View {
        Menu {
            Picker("Group", selection: Binding(
                get: { tile.groupID },
                set: { id in onAssign(groups.first { $0.id == id }) }
            )) {
                Text(LibraryLayout.ungroupedTitle).tag(UUID?.none)
                ForEach(groups, id: \.id) { group in
                    Text(group.name).tag(UUID?.some(group.id))
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.footnote)
                .foregroundStyle(.tint)
        }
        .accessibilityLabel("Group for \(tile.name)")
    }
}

#Preview {
    VStack {
        ExerciseTile(
            tile: LibraryTile(
                exercise: Exercise(name: "Bulgarian Split Squat"),
                lastEntry: LastEntry(reps: 8, weight: 52.5, date: .now)
            ),
            onOpen: {}
        )
        ExerciseTile(
            tile: LibraryTile(exercise: Exercise(name: "Ab Wheel"), lastEntry: nil),
            arranging: true,
            groups: [ExerciseGroup(name: "Core", sortIndex: 0)],
            onOpen: {}
        )
    }
    .padding()
}
