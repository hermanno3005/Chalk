import SwiftUI

// Chalk's palette and type (SPEC §15.4), from the identity prototype's tokens
// (`docs/prototypes/identity/README.md`): monochrome white or black with one cool grey,
// SF Pro semibold by default, and the goal kept orange. The colours are assets —
// `AccentColor` (black or white), `Ground`, `Grey`, `OnAccent` and `Goal` — so the
// system's own controls, alerts and menus take the accent too, and nothing draws a
// system blue. **Text on an accent fill is the inverse**, `Color.onAccent`: the Log
// bars, the selected zone and every prominent button, whose label the system would
// otherwise draw white on white in dark.

extension Color {
    /// What a tile, a card or a field sits on: the cool grey, faint over the ground, in
    /// place of the system's bluish secondary background.
    static let surface = Color.grey.opacity(0.16)
}

extension View {
    /// A list section's rows on the ground, which a list's own background never reaches:
    /// in a sheet in dark the system lifts them to its elevated grey, and an inset form
    /// would draw them as cards in dark only. **Every `Section` in a list or form takes
    /// it**, with its header and footer in `.secondary`, since the screen's foreground
    /// style otherwise reaches them as the primary.
    func chalkRows() -> some View {
        listRowBackground(Color.ground)
    }

    /// Draws a screen on the ground, in SF Pro semibold, with `.secondary` and
    /// `.tertiary` resolving to the cool grey. **Every screen and every sheet opens with
    /// it**, since a pushed screen and a sheet each draw their own background, and a
    /// sheet in dark would otherwise lift to the system's elevated grey.
    func chalkScreen() -> some View {
        modifier(ChalkScreen())
    }
}

private struct ChalkScreen: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.ground)
            .presentationBackground(Color.ground)
            .fontWeight(.semibold)
            .foregroundStyle(Color.primary, Color.grey, Color.grey.opacity(0.45))
    }
}
