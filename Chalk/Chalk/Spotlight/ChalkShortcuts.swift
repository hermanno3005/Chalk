import AppIntents

/// Chalk's App Shortcuts (SPEC §15.5): the rep-max card, and an opener for every exercise
/// and erg. Each gives a Spotlight tile per suggested entity and a Siri phrase.
///
/// **Every phrase names Chalk**, as App Shortcuts require, and Chalk declares no other
/// name for itself: a generic synonym such as *rep max* breaks App Review Guideline
/// 2.5.11.
struct ChalkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RepMaxesIntent(),
            phrases: [
                "\(\.$exercise) rep maxes in \(.applicationName)",
                "What's my 5 rep max on \(\.$exercise) in \(.applicationName)",
            ],
            shortTitle: "Rep-Maxes",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: OpenExerciseIntent(),
            phrases: ["Open \(\.$target) in \(.applicationName)"],
            shortTitle: "Open Exercise",
            systemImageName: "dumbbell"
        )
        AppShortcut(
            intent: OpenErgIntent(),
            phrases: ["Open \(\.$target) in \(.applicationName)"],
            shortTitle: "Open Erg",
            systemImageName: "figure.rower"
        )
    }

    /// Apple's cap on an app's trigger phrases, **counting each phrase once per suggested
    /// entity** (WWDC23 10102).
    static let phraseLimit = 1_000

    /// The phrases above that take an exercise, and those that take an erg. **Change these
    /// with the phrases**: they decide how many rows the suggestions can hold.
    static let phrasesPerExercise = 3
    static let phrasesPerErg = 1
}
