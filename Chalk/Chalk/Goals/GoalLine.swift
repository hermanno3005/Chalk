import Foundation

/// The one line a goal gets on a detail screen, under the readout's subhead, in either
/// half: `Goal 140 × 5 · 40 kg to go`, `Goal 15.5 km/h · 6:00 in Z4 · 1 % · 0.4 km/h to
/// go`, led by a donut filled to `progress`. **It stays once reached**, greyed and
/// reading `· reached` — no celebration, and no vanishing (SPEC §12.4, §13.10).
///
/// Strength's is built by `ExerciseDetailModel.goalLine`, an erg's by
/// `GoalLine(endurance:)`; `GoalLineView` draws both.
struct GoalLine: Equatable {
    let text: String
    let isReached: Bool
    /// The donut's fill, 0…1.
    let progress: Double
}
