import Foundation
import Observation
import SwiftData

/// The endurance goal sheet's state (SPEC §13.10): **a short form, not the two-stage
/// giant number** — a zone, a duration, an incline on a speed erg, and an intensity —
/// naming a point on the zone line you have not held yet (ADR-0007).
///
/// Its rows are typed on **the lap-list grid's keypad, through the same
/// `EnduranceInput`**, so a duration fills from the right and a speed takes one tenth here
/// exactly as in the grid; nothing is copied. As strength's goal sheet, it has **no
/// machine caption** — the scope is the one the detail screen is showing — and **no
/// seeded intensity**, because a goal is by definition a number you have not held.
@Observable
final class EnduranceGoalSheetModel: Identifiable {

    let id = UUID()

    let unit: ErgUnit

    /// `Z1`–`Z5`, segmented. Nil only with nothing scrubbed to seed it from.
    var zone: Int?

    /// The rows under the zone, top to bottom: duration, incline on a speed erg only, and
    /// intensity.
    let rows: [EnduranceField]

    /// The row the keypad is typing into.
    private(set) var focus: EnduranceField?

    /// Whether a goal is set here now — what puts `Clear goal` at the foot of the sheet.
    let hasGoal: Bool

    private var inputs: [EnduranceField: EnduranceInput]

    @ObservationIgnored private let scope: GoalScope
    @ObservationIgnored private let zones: HeartRateZones
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let onChange: () -> Void
    /// The entries the line reads, once at open: the sheet closes on the only write that
    /// could change them.
    @ObservationIgnored private let entries: [Entry]

    /// Nil **before zones are set** — no goal may name a zone that does not exist yet —
    /// and on a lift's scope. `selection` is where the detail screen was scrubbed to; it
    /// seeds the zone, duration and incline.
    init?(
        scope: GoalScope,
        selection: ErgReading.Selection?,
        zones: HeartRateZones?,
        context: ModelContext,
        onChange: @escaping () -> Void = {}
    ) {
        guard let zones, let unit = scope.unit else { return nil }
        self.unit = unit
        self.scope = scope
        self.zones = zones
        self.context = context
        self.onChange = onChange
        entries = scope.entries
        hasGoal = scope.enduranceGoal(zones: zones) != nil

        // The point first, then the number at it — not the grid's watch order.
        rows = unit == .speed ? [.duration, .incline, .intensity] : [.duration, .intensity]
        zone = selection?.zone
        inputs = [
            .duration: EnduranceInput(.duration, unit: unit, value: selection.map { Double($0.duration) }),
            .incline: EnduranceInput(.incline, unit: unit, value: selection?.incline),
            .intensity: EnduranceInput(.intensity, unit: unit),
        ]
        // The keypad opens on the first blank row: the intensity, wherever there was a
        // point to seed from.
        focus = rows.first { inputs[$0]?.value == nil }
    }

    /// What a row shows: the keys as typed, or the value in its format.
    func text(_ field: EnduranceField) -> String {
        inputs[field]?.text ?? ""
    }

    /// Moves the keypad to another row, settling the one it leaves — a stray tap puts
    /// its seed back.
    func select(_ field: EnduranceField) {
        guard rows.contains(field), field != focus else { return }
        if let focus { inputs[focus]?.settle() }
        focus = field
    }

    /// One key into the focused row.
    func type(_ key: TwoStageNumber.Key) {
        guard let focus else { return }
        inputs[focus]?.type(key)
    }

    /// Whether the keypad's decimal key is live on the focused row.
    var decimalIsDead: Bool {
        !(focus.flatMap { inputs[$0]?.takesDecimal } ?? false)
    }

    // MARK: - Set and Clear

    /// **Every field filled**: a zone, a duration and an intensity above nothing, and an
    /// incline on a speed erg — 0 % is a value. No ceiling: a goal over 20:00 is valid,
    /// and a goal already reached is noted by the line, not refused.
    var canSetGoal: Bool {
        guard let goal = goal(intensity: value(.intensity) ?? 0) else { return false }
        return goal.intensity > 0
    }

    /// **Setting a goal**: replaces whatever was here and restarts the ring from now.
    func setGoal() {
        guard canSetGoal, let goal = goal(intensity: value(.intensity) ?? 0) else { return }
        scope.set(
            zone: goal.zone,
            duration: goal.duration,
            intensity: unit.rounded(goal.intensity),
            incline: goal.incline
        )
        save()
    }

    /// **Clearing a goal**, with no confirmation (§12.3): naming one again is a few keys
    /// away.
    func clearGoal() {
        scope.clear()
        save()
    }

    private func save() {
        // As elsewhere: v1 has no error state past §3's container failure.
        try? context.save()
        onChange()
    }

    // MARK: - The live line

    /// The one line under the intensity: how the goal on screen stands against **the
    /// exact point the rows name** — its ten-visit mean, read through `EnduranceGoal` so
    /// the steps compare as they will on the detail screen. Grey where the number is one
    /// you already hold.
    ///
    /// Nil until the rows name a point, and — at a point you have held — until there is
    /// an intensity to compare: "already reached" at nothing would be true and useless.
    var line: GoalSheetModel.Line? {
        guard let goal = goal(intensity: value(.intensity) ?? 0) else { return nil }
        let point = "\(EnduranceText.clock(goal.duration)) in Z\(goal.zone)"
        guard let current = goal.current, let gap = goal.gap else {
            return .init(text: "Not held yet — \(goal.pointText)", isReached: false)
        }
        guard goal.intensity > 0 else { return nil }
        if gap > 0 {
            return .init(text: "\(EnduranceText.steps(gap, unit)) above your \(point)", isReached: false)
        }
        return .init(
            text: "Already reached — your \(point) is \(EnduranceText.intensity(current, unit, pace: false))",
            isReached: true
        )
    }

    /// The goal the rows spell, judged against the scope's entries as of now; nil while
    /// the point is not fully named.
    private func goal(intensity: Double) -> EnduranceGoal? {
        guard let duration = value(.duration), duration > 0 else { return nil }
        return EnduranceGoal(
            zone: zone,
            duration: Int(duration.rounded()),
            intensity: intensity,
            incline: value(.incline),
            setAt: .now,
            entries: entries,
            zones: zones,
            unit: unit
        )
    }

    private func value(_ field: EnduranceField) -> Double? {
        rows.contains(field) ? inputs[field]?.value : nil
    }
}
