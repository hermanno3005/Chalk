import SwiftUI

/// The last thing you logged, at the top of the library (SPEC §7.1). **The single
/// likeliest thing you want, so it gets the biggest target on the screen**: the card
/// body pushes the exercise's detail screen, and *Log again* opens the log sheet.
///
/// *Log again* is the one `Button` on this screen — nothing drags a resume card, so
/// SPEC §7.2's second hazard does not apply to it. The body around it stays a plain view
/// with a tap gesture so the button keeps its own press.
struct ResumeCard: View {
    let resume: LibraryResume
    let onOpen: () -> Void
    let onLogAgain: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(resume.exercise.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(resume.lastEntry.text())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens this exercise")

            Button("Log again", action: onLogAgain)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    ResumeCard(
        resume: LibraryResume(
            exercise: Exercise(name: "Bench Press"),
            lastEntry: LastEntry(reps: 8, weight: 52.5, date: .now)
        ),
        onOpen: {},
        onLogAgain: {}
    )
    .padding()
}
