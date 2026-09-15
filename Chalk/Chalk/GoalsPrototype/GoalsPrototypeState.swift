import Foundation
import SwiftUI

// PROTOTYPE — throwaway. Answers "How is a goal presented?" (issue #64).
// Four variants of the goal on the exercise detail screen, switchable from the
// floating bottom bar, over three datasets, three goal states, and a ghost toggle.
// In memory only: no SwiftData container, no persistence, nothing to wipe.

/// A goal, exactly as the map settled it: `(reps, weight)` on one scope, reached when
/// `best[reps] >= weight`. Nothing is stored about reaching it.
struct PrototypeGoal {
    let reps: Int
    let weight: Double

    func isReached(_ curve: RepMaxCurve) -> Bool {
        (curve.best[reps] ?? 0) >= weight
    }

    /// `goal weight − best[reps]`, floored at zero. With nothing logged it is the
    /// whole weight.
    func gap(_ curve: RepMaxCurve) -> Double {
        max(0, weight - (curve.best[reps] ?? 0))
    }
}

/// What the switcher varies. Every axis is a case the decision has to survive.
enum PrototypeDataset: String, CaseIterable {
    case none = "0 entries"
    case sparse = "1 entry"
    case typical = "6 entries"

    var entries: [Entry] {
        switch self {
        case .none: []
        case .sparse: [Entry(reps: 5, weight: 80)]
        case .typical: [
            Entry(reps: 1, weight: 120), Entry(reps: 3, weight: 110),
            Entry(reps: 5, weight: 100), Entry(reps: 6, weight: 97.5),
            Entry(reps: 8, weight: 85), Entry(reps: 12, weight: 70),
        ]
        }
    }
}

/// Where the goal sits relative to the curve. `reached` is the state whose appearance
/// the ticket asks us to settle.
enum PrototypeGoalState: String, CaseIterable {
    case far = "far"
    case close = "close"
    case reached = "reached"
    case unset = "no goal"

    /// Chosen against the `typical` dataset, whose `best[5]` is 100 kg.
    var goal: PrototypeGoal? {
        switch self {
        case .far: PrototypeGoal(reps: 5, weight: 140)
        case .close: PrototypeGoal(reps: 5, weight: 102.5)
        case .reached: PrototypeGoal(reps: 5, weight: 95)
        case .unset: nil
        }
    }
}

/// The two answers to "what does a reached goal look like" the ticket names.
enum ReachedStyle: String, CaseIterable {
    case grey = "grey out"
    case vanish = "vanish"
}

enum PrototypeVariant: String, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var name: String {
        switch self {
        case .a: "Curve marker"
        case .b: "Gap under readout"
        case .c: "Card in the empty space"
        case .d: "The gap is the headline"
        }
    }
}

@Observable
final class GoalsPrototypeModel {
    var variant: PrototypeVariant = .a
    var dataset: PrototypeDataset = .typical
    var goalState: PrototypeGoalState = .far
    var reachedStyle: ReachedStyle = .grey
    /// The fog the map is carrying: does the ghost still earn its pixels once a goal
    /// is named? Flip it and look.
    var showGhost = true
    /// Sticky, exactly as the real screen's is.
    var selectedReps = 5

    /// Screenshots are taken by launching with `-variant A -dataset "6 entries"` and
    /// friends, so each combination is captured deterministically rather than by
    /// tapping the switcher.
    init() {
        let args = UserDefaults.standard
        if let v = args.string(forKey: "variant"), let m = PrototypeVariant(rawValue: v) { variant = m }
        if let v = args.string(forKey: "dataset"), let m = PrototypeDataset(rawValue: v) { dataset = m }
        if let v = args.string(forKey: "goal"), let m = PrototypeGoalState(rawValue: v) { goalState = m }
        if let v = args.string(forKey: "reached"), let m = ReachedStyle(rawValue: v) { reachedStyle = m }
        if args.object(forKey: "ghost") != nil { showGhost = args.bool(forKey: "ghost") }
    }

    var entries: [Entry] { dataset.entries }
    var curve: RepMaxCurve { RepMaxCurve(entries: entries) }
    var hasCurve: Bool { !entries.isEmpty }

    /// `nil` when there is no goal, and — under `vanish` — when the goal is reached.
    var goal: PrototypeGoal? {
        guard let goal = goalState.goal else { return nil }
        if goal.isReached(curve) && reachedStyle == .vanish { return nil }
        return goal
    }

    var isReached: Bool { goal.map { $0.isReached(curve) } ?? false }

    var gap: Double { goal.map { $0.gap(curve) } ?? 0 }

    func select(_ reps: Int?) {
        if let reps { selectedReps = reps }
    }

    func cycleVariant(_ step: Int) { variant = Self.cycle(variant, step) }

    static func cycle<T: CaseIterable & Equatable>(_ value: T, _ step: Int) -> T
    where T.AllCases: RandomAccessCollection, T.AllCases.Index == Int {
        let all = T.allCases
        let i = all.firstIndex(of: value) ?? 0
        return all[(i + step + all.count) % all.count]
    }
}
