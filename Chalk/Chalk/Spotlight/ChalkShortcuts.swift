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

    /// The rows whose phrases fit under Apple's cap of 1,000 trigger phrases, **each
    /// phrase counted once per suggested entity** (WWDC23 10102): every one in a library
    /// of any size Chalk expects, and otherwise the first of `ranked` that fit.
    ///
    /// It stops at the first row that doesn't fit rather than skipping to a cheaper one,
    /// so what is cut is always the end of `ranked`.
    static func fitting(_ ranked: [IndexedRow]) -> [IndexedRow] {
        var phrasesLeft = 1_000
        var fitting: [IndexedRow] = []
        for row in ranked {
            let phrases = row.half == .strength ? phrasesPerExercise : phrasesPerErg
            guard phrases <= phrasesLeft else { break }
            phrasesLeft -= phrases
            fitting.append(row)
        }
        return fitting
    }

    /// The phrases above that take an exercise, and those that take an erg. **Change these
    /// with the phrases**: they decide how many rows the suggestions can hold.
    private static let phrasesPerExercise = 3
    private static let phrasesPerErg = 1
}
