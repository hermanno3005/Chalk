import AppIntents
import SwiftUI

/// What *Bench press rep maxes in Chalk* runs, from Siri or its Spotlight tile: the
/// exercise's rep-max card, shown **without opening Chalk** (SPEC §15.5).
///
/// It takes the exercise and **no rep count**, because a phrase carries one value. Strength
/// only: an erg has no single number to read out, so the parameter is an `ExerciseEntity`.
struct RepMaxesIntent: AppIntent {
    static var title: LocalizedStringResource { "Rep-Maxes" }
    static var description: IntentDescription {
        "Shows your twelve rep-maxes on an exercise, on the machine its screen opens on."
    }

    @Parameter(title: "Exercise") var exercise: ExerciseEntity
    @Dependency private var router: LibraryRouter

    static var parameterSummary: some ParameterSummary {
        Summary("Rep-maxes on \(\.$exercise)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView & ReturnsValue<String> {
        let card = try router.repMaxCard(for: exercise.id)
        return .result(
            value: card.summary,
            dialog: "Here are your rep-maxes on \(card.name).",
            view: RepMaxCardView(card: card)
        )
    }
}

/// The rep-max card as Siri and Spotlight draw it: the name in grey, the machine under it
/// when gym-bound, then the twelve rep-maxes four to a row, or the line that says nothing
/// is logged. **A tap opens the exercise's detail screen** through the same Open intent a
/// Spotlight result runs, so it lands on the same numbers.
///
/// **It sets its grey and its weight itself** rather than through `chalkScreen()`: Siri
/// draws it on a platter of its own, so there is no Chalk screen for it to open on.
struct RepMaxCardView: View {
    let card: RepMaxCard

    private static let columns = 4

    var body: some View {
        Button(intent: OpenExerciseIntent(target: ExerciseEntity(id: card.exerciseID, name: card.name))) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                    if let machine = card.machine {
                        Text(machine)
                            .font(.footnote)
                            .accessibilityLabel(card.spokenMachine ?? machine)
                    }
                }
                .foregroundStyle(Color.grey)

                if let nothingLogged = card.nothingLogged {
                    Text(nothingLogged)
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        ForEach(Array(stride(from: 0, to: card.cells.count, by: Self.columns)), id: \.self) { start in
                            GridRow {
                                ForEach(card.cells[start..<min(start + Self.columns, card.cells.count)], id: \.reps) { cell in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("× \(cell.reps)")
                                            .font(.caption)
                                            .foregroundStyle(Color.grey)
                                        Text(cell.text)
                                            .fontWeight(.bold)
                                            .monospacedDigit()
                                    }
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(cell.spoken)
                                }
                            }
                        }
                    }
                }
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .buttonStyle(.plain)
    }
}
