import UIKit

/// What a Save plays (SPEC §15.4): **the success tap for any entry, and a distinct one
/// when the save reaches a goal**, in place of it. A block of intervals plays once per
/// Save, as it is one visit.
///
/// **The sheets decide which, and the views only play it**: the log sheets' `save()`
/// answers with one, and the Save button plays it as the sheet closes.
enum SaveHaptic: Equatable {
    case saved
    case reachedGoal

    /// Played straight from the Save button rather than from a view's state: the sheet
    /// is dismissed in the same tap, and a `sensoryFeedback` on a closing sheet is not
    /// promised to fire.
    @MainActor
    func play() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard self == .reachedGoal else { return }
        // Saved, and more: the same tap, then a heavy one after it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}
