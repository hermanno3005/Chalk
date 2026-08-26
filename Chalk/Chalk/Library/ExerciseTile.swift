import SwiftUI

/// One exercise in the grid.
///
/// **A plain view with a tap gesture, not a `Button`** — SPEC §7.2's second hazard: a
/// button's own gesture claims the press, so `.draggable` on it rarely fires, and
/// Arrange mode (#30) puts dragging on this same tile. For the same reason it carries no
/// `.contextMenu`: both are long-press driven and the menu wins every time.
///
/// The `8 × 52.5 kg · today` subtitle needs entries and arrives with the resume card (#25).
struct ExerciseTile: View {
    let exercise: Exercise
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
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
    ExerciseTile(exercise: Exercise(name: "Bulgarian Split Squat"), onOpen: {})
        .padding()
}
