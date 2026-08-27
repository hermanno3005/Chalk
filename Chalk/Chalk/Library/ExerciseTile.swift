import SwiftUI

/// One exercise in the grid: its name, and what you last did for it (SPEC §7.1).
///
/// **A plain view with a tap gesture, not a `Button`** — SPEC §7.2's second hazard: a
/// button's own gesture claims the press, so `.draggable` on it rarely fires, and
/// Arrange mode (#30) puts dragging on this same tile. For the same reason it carries no
/// `.contextMenu`: both are long-press driven and the menu wins every time.
struct ExerciseTile: View {
    let tile: LibraryTile
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tile.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)

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
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
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
            onOpen: {}
        )
    }
    .padding()
}
