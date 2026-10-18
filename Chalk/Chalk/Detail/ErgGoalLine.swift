import SwiftUI

extension ExerciseDetailModel.GoalLine {
    /// The erg detail screen's goal line (SPEC §13.10): `Goal 15.5 km/h · 6:00 in Z4 · 1 %
    /// · 0.4 km/h to go`, `· reached`, or `· not held yet` — **no pace**, so it stays
    /// short — led by the same donut, filled from the goal's origin.
    init(endurance goal: EnduranceGoal) {
        self.init(
            text: "Goal \(goal.text) · \(goal.status)",
            isReached: goal.isReached,
            progress: goal.progress
        )
    }
}

/// The goal line under the erg readout, **whatever zone is selected**, and under the text
/// in the nothing-logged state, as strength's sits (§5.4). Orange, grey once reached, no
/// celebration, **never drawn on the chart** (§12.4) — tapping it opens the goal sheet.
struct ErgGoalLine: View {
    let line: ExerciseDetailModel.GoalLine
    let onTap: () -> Void

    var body: some View {
        GoalLineView(line: line)
            .onTapGesture(perform: onTap)
    }
}
