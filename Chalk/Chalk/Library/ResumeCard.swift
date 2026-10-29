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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // *Log again* drops under the text at an accessibility size, which would
        // otherwise squeeze the name to a word a line (SPEC §15.6).
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 4) {
                Text(resume.exercise.name)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    goalSlot
                    Text(resume.text())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens this exercise")

            Button("Log again", action: onLogAgain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.onAccent)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        }
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    /// The goal's ring, with no words, in a slot **reserved whether or not there is a
    /// goal**: every card's subtitle is indented the same, so the card never changes shape
    /// as goals come and go. Empty means no goal — not a hairline, not an empty ring.
    ///
    /// Inert: it sits inside the card body, so a tap on it opens the exercise like any
    /// other tap there, and it is never a target between *Log again* and the card.
    private var goalSlot: some View {
        ZStack {
            if let ring = resume.ring {
                GoalDonut(progress: ring.progress, isReached: ring.isReached)
            }
        }
        .frame(width: GoalDonut.size, height: GoalDonut.size)
    }
}

#Preview {
    // No goal, a goal with nothing logged toward it yet (an empty ring), reached.
    let lastEntry = LastEntry(reps: 8, weight: 52.5, date: .now)
    let goals: [Goal?] = [
        nil,
        Goal(reps: 8, weight: 60, setAt: .now, entries: []),
        Goal(reps: 8, weight: 0, setAt: .now, entries: []),
    ]
    VStack(spacing: 12) {
        ForEach(goals.indices, id: \.self) { index in
            ResumeCard(
                resume: LibraryResume(
                    exercise: Exercise(name: "Bench Press"),
                    lastEntry: lastEntry,
                    goal: goals[index],
                    weightUnit: .kg,
                    distanceUnit: .km
                ),
                onOpen: {},
                onLogAgain: {}
            )
        }
    }
    .padding()
}
