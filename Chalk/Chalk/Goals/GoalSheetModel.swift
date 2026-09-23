import Foundation
import Observation
import SwiftData

/// The goal sheet's state (#74): **the log sheet's two-stage number borrowed whole** —
/// reps, then weight, the same steppers, keypad, snapping and clamps — naming a goal
/// instead of logging an entry.
///
/// What it leaves out is the point: **no machine caption**, because the scope is always
/// the one the detail screen is showing; **no seeded weight**, because a goal is by
/// definition a number you have not lifted; and **no verdict**, replaced by a line that
/// says how far the number on screen is from your best.
@Observable
final class GoalSheetModel: Identifiable {

    let id = UUID()

    /// The line under the weight: how far the goal on screen is from your best at its
    /// rep count. Drawn in the goal colour, and grey where the number is one you have
    /// already lifted.
    struct Line: Equatable {
        let text: String
        let isReached: Bool
    }

    /// The giant number, shared with the log sheet (#73). Seeded with reps only.
    var number: TwoStageNumber

    /// Whether a goal is set here now — what puts `Clear goal` at the foot of the sheet.
    let hasGoal: Bool

    @ObservationIgnored private let scope: GoalScope
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let onChange: () -> Void
    /// The entries the line compares against, read once at open: the sheet closes on the
    /// only write that could change them.
    @ObservationIgnored private let entries: [Entry]

    /// `reps` is where the detail screen was scrubbed to — the caller's answer, as the
    /// scope is.
    init(
        scope: GoalScope,
        reps: Int,
        context: ModelContext,
        onChange: @escaping () -> Void = {}
    ) {
        self.scope = scope
        self.context = context
        self.onChange = onChange
        entries = scope.entries
        hasGoal = scope.goal != nil
        // **The weight opens blank with the keypad up** — the app never suggests a load
        // it cannot back up, and a goal is one you have not lifted.
        number = TwoStageNumber(reps: reps, weight: nil)
    }

    /// **Weight stage only**, like the log sheet's verdict: until there is a weight there
    /// is nothing to compare. A blank weight says nothing rather than reading as zero —
    /// "already reached" at 0 kg would be true and useless.
    var line: Line? {
        guard number.stage == .weight, let reps = number.reps else { return nil }
        guard let best = RepMaxCurve.best(atLeast: reps, in: entries) else {
            return Line(text: "First goal at \(reps) reps", isReached: false)
        }
        guard let weight = number.weight, weight > 0 else { return nil }
        if weight > best {
            return Line(text: "\((weight - best).kilogramsText) kg above your \(reps)-rep best", isReached: false)
        }
        return Line(text: "Already reached — your \(reps)-rep best is \(best.kilogramsText) kg", isReached: true)
    }

    /// `reps >= 1` and `weight > 0`, and nothing more: **no ceiling ever blocks a real
    /// target**, and a goal you have already reached is noted by the line, not refused.
    var canSetGoal: Bool { number.canAdvance && (number.weight ?? 0) > 0 }

    /// **Setting a goal**: replaces whatever was here and restarts the ring from now.
    func setGoal() {
        guard canSetGoal, let reps = number.reps, let weight = number.weight else { return }
        scope.set(reps: reps, weight: weight)
        save()
    }

    /// **Clearing a goal**, with no confirmation: re-setting one is two stages away.
    func clearGoal() {
        scope.clear()
        save()
    }

    private func save() {
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        onChange()
    }
}
