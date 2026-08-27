import SwiftUI

/// **The app's one machine picker** (SPEC §5.3, §6.4): every machine for one exercise,
/// flat, sectioned by gym, each row reading `label · gym`. One behaviour, learned once —
/// the detail screen's nav-bar qualifier and the log sheet's caption open the same thing.
///
/// Menu *content*, not a menu: the caller supplies the `Menu` and its label, so the same
/// rows sit under a nav-bar button and under a caption line without either being a
/// special case.
///
/// The two rows only the log sheet needs are optional and absent by default (#28). The
/// nav-bar menu resolves a machine that already exists; **creating one belongs where the
/// hole is** — the first gym-bound log at a gym with no machine for that exercise.
struct MachinePicker: View {
    let menu: MachineMenu
    /// The machine the screen is scoped to, ticked in the list.
    let selected: Machine?
    let onSelect: (Machine) -> Void

    /// `New machine here`, one per gym section — the gym is implied by the section, so
    /// there is no gym picker and no second decision.
    var onNewMachine: ((Gym) -> Void)?
    /// `New gym…`, at the very bottom. Standing in an unfamiliar gym is exactly when you
    /// need one.
    var onNewGym: (() -> Void)?

    var body: some View {
        ForEach(menu.sections) { section in
            Section(section.title) {
                ForEach(section.machines, id: \.id) { machine in
                    Button {
                        onSelect(machine)
                    } label: {
                        // The tick is the only difference between the rows: the menu is
                        // a picker, so what it is showing has to be visible in it.
                        if machine === selected {
                            Label(machine.caption, systemImage: "checkmark")
                        } else {
                            Text(machine.caption)
                        }
                    }
                }
                // Never in the `Archived` section: it is the tail of a picker, and
                // making a machine at a gym you have stopped visiting is not a thing to
                // offer one tap from the log path.
                if let onNewMachine, let gym = section.gym, !section.isArchived {
                    Button("New machine here", systemImage: "plus") { onNewMachine(gym) }
                }
            }
        }
        if let onNewGym {
            Section {
                Button("New gym…", systemImage: "building.2") { onNewGym() }
            }
        }
    }
}
