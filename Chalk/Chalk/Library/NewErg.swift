import Foundation

/// The create-erg sheet's four answers (SPEC §13.6), as a value the sheet edits and
/// `LibraryModel.create(_:)` reads — so the unit gate is one rule, held here, rather than
/// a `.disabled` the model could be called around.
struct NewErg: Equatable {
    /// Plain text, **with no suggestions**: Chalk keeps no vocabulary of machines.
    var name: String
    /// **Starts on none.** Chalk never guesses a unit, because once the erg has entries a
    /// unit has no repair.
    var unit: ErgUnit?
    /// **Starts on gym-bound**, the cheaper mistake: a cold start and a hint, rather than
    /// pooling numbers that should never meet. `.freeWeight` is transferable on an erg.
    var kind: ExerciseKind = .gymBound
    /// The endurance group it is filed on; `nil` is Ungrouped, the default.
    var groupID: UUID?

    init(name: String = "") {
        self.name = name
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// **Save stays disabled until a unit is chosen**, so no erg exists without one — and,
    /// as for any exercise, until it has a name.
    var canSave: Bool { unit != nil && !trimmedName.isEmpty }
}
