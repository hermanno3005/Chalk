import SwiftUI

/// **A log sheet's machine caption** (SPEC §6.4, §13.7) — strength's above the giant
/// number, endurance's once above the grid. It reads as a caption, not a control, so the
/// numbers stay the only thing on the sheet with weight; tapping it opens **the app's
/// one machine picker** (§5.3), plus the two rows only a log sheet needs: `New machine
/// here` in each gym section, and `New gym…` at the bottom.
///
/// The sheet draws none at all where its `MachineCaption.text` is nil — a free-weight
/// exercise or a transferable erg carries no machine row.
struct MachineCaptionMenu: View {
    let text: String
    let menu: MachineMenu
    let selected: Machine?
    let onSelect: (Machine) -> Void
    let onNewMachine: (Gym) -> Void
    let onNewGym: () -> Void

    var body: some View {
        Menu {
            MachinePicker(
                menu: menu,
                selected: selected,
                onSelect: onSelect,
                onNewMachine: onNewMachine,
                onNewGym: onNewGym
            )
        } label: {
            Label(text, systemImage: "square.stack.3d.up")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 8)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Changes the machine this is logged on")
    }
}
