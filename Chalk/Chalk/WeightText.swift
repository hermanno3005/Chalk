import Foundation

/// How Chalk writes a weight. **Kilograms, always** (SPEC §2) — half plates matter, so
/// one fraction digit survives; trailing zeroes do not, so `60` is not `60.0`.
///
/// Locale-aware, like every number the app shows: the log sheet's keypad types a `.`
/// into its draft because that is what `Double` parses, and displays whatever a decimal
/// point looks like where you are standing.
enum WeightText {
    static var decimalSeparator: String { Locale.current.decimalSeparator ?? "." }
}

extension Double {
    /// The number alone — callers add the `kg`, because some of them put other words
    /// between the two.
    var kilogramsText: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}
