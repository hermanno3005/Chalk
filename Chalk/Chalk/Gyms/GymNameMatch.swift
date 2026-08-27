import Foundation

/// The near-name warning shown at every gym-creation door — the library's Gym menu, the
/// create-exercise sheet, and the log sheet's `New gym…` (SPEC §7.4).
///
/// **Duplicates are prevented, not merged.** There is no gym merge, and the repair for
/// one that slipped through is moving each machine across by hand, so the cheap moment to
/// catch it is while the name is being typed. It **warns**, never blocks: two gyms really
/// can be called *Fitness X*.
enum GymNameMatch {

    /// An existing gym the typed name looks like, or `nil` when it looks like none.
    ///
    /// Matching is deliberately loose in three ways an actual duplicate arrives:
    /// re-typed with different case, spacing or accents; one letter off; or the same gym
    /// with the branch appended. It is deliberately **not** loose on short names, where
    /// a single letter is the whole difference between *RSG* and *PSG*.
    static func nearMatch(for name: String, among gyms: [Gym]) -> Gym? {
        let typed = normalised(name)
        guard !typed.isEmpty else { return nil }

        return gyms.first { gym in
            let existing = normalised(gym.name)
            guard !existing.isEmpty else { return false }
            if existing == typed { return true }
            // The same gym with a branch or a district appended, either way round.
            if typed.count >= minimumStemLength || existing.count >= minimumStemLength,
               typed.hasPrefix(existing) || existing.hasPrefix(typed) {
                return true
            }
            // One letter off — but only where a letter is not the whole name.
            guard min(typed.count, existing.count) >= minimumTypoLength else { return false }
            return editDistance(typed, existing) <= 1
        }
    }

    /// Lowercased, accent-folded, punctuation-free, with runs of whitespace collapsed:
    /// *`  Café   Gym `* and *`cafe gym`* are the same gym typed twice.
    private static func normalised(_ name: String) -> String {
        name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Below this, one name extending another says nothing — *X* prefixes half the gyms
    /// in the world.
    private static let minimumStemLength = 4

    /// Below this, a single letter is the name rather than a typo in it.
    private static let minimumTypoLength = 5

    /// Levenshtein distance, two rows at a time. The names are short, and this runs once
    /// per existing gym per keystroke.
    private static func editDistance(_ left: String, _ right: String) -> Int {
        let left = Array(left)
        let right = Array(right)
        guard !left.isEmpty else { return right.count }
        guard !right.isEmpty else { return left.count }

        var previous = Array(0...right.count)
        var current = previous
        for (row, leftCharacter) in left.enumerated() {
            current[0] = row + 1
            for (column, rightCharacter) in right.enumerated() {
                let substitution = previous[column] + (leftCharacter == rightCharacter ? 0 : 1)
                current[column + 1] = min(substitution, previous[column + 1] + 1, current[column] + 1)
            }
            swap(&previous, &current)
        }
        return previous[right.count]
    }
}
