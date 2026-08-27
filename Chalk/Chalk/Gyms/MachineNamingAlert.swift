import SwiftUI

/// `Name this machine` — the one optional field behind both doors that make a machine:
/// the log sheet's `New machine here` (SPEC §6.4) and `Change kind`'s machine prompt
/// (§8).
///
/// **Always asked, never required.** You cannot know at creation time whether a second
/// machine is coming, so the question is put every time; and a machine is often just the
/// leg press by the window with nothing written on it, so `Skip` is a real answer and
/// leaves it `Unlabelled` (§7.5).
///
/// The gym is implied by where the row was tapped — it is what `gym` holds while the
/// alert is up — so there is no gym picker here and no second decision.
struct MachineNamingAlert: ViewModifier {
    /// The gym the machine is being made at, and the alert's own presentation: non-nil
    /// exactly while it is up.
    @Binding var gym: Gym?
    /// The answer, `nil` where you skipped it.
    let onName: (Gym, String?) -> Void

    @State private var draft = ""

    func body(content: Content) -> some View {
        content.alert("Name this machine", isPresented: isPresented, presenting: gym) { gym in
            TextField("Optional", text: $draft)
            Button("Add") { onName(gym, draft) }
            Button("Skip") { onName(gym, nil) }
        } message: { _ in
            Text("Optional — you can leave it unnamed.")
        }
        // A name typed and then cancelled is not the next machine's name.
        .onChange(of: gym == nil) { _, dismissed in
            if dismissed { draft = "" }
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { gym != nil }, set: { if !$0 { gym = nil } })
    }
}

extension View {
    /// Puts `Name this machine` over this view for the gym `gym` holds, and hands back
    /// the answer.
    func namingMachine(at gym: Binding<Gym?>, onName: @escaping (Gym, String?) -> Void) -> some View {
        modifier(MachineNamingAlert(gym: gym, onName: onName))
    }
}
