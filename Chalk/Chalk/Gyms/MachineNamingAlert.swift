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
///
/// **On an erg, a name that looks like its machine at another gym is asked about once
/// more** (SPEC §13.11): *You have a Technogym Excite at FitX — same model?*, offering
/// that spelling or the one typed. It warns and never blocks — both answers make the
/// machine, and dismissing it keeps what you typed.
struct MachineNamingAlert: ViewModifier {
    /// The gym the machine is being made at, and the alert's own presentation: non-nil
    /// exactly while it is up.
    @Binding var gym: Gym?
    /// The near-name check for this door — `ErgModelMatch.onCreate` through the model
    /// behind it; always `nil` for a lift.
    let check: (Gym, String?) -> ErgModelMatch?
    /// The answer, `nil` where you skipped it.
    let onName: (Gym, String?) -> Void

    @State private var draft = ""
    /// The near name the typed one was found to look like, waiting on its answer.
    @State private var warning: Warning?

    private struct Warning {
        let gym: Gym
        let match: ErgModelMatch
    }

    func body(content: Content) -> some View {
        content.alert("Name this machine", isPresented: isPresented, presenting: gym) { gym in
            TextField("Optional", text: $draft)
            Button("Add") { named(gym, draft) }
            Button("Skip") { onName(gym, nil) }
        } message: { _ in
            Text("Optional — you can leave it unnamed.")
        }
        // A name typed and then cancelled is not the next machine's name.
        .onChange(of: gym == nil) { _, dismissed in
            if dismissed { draft = "" }
        }
        .alert(
            warning?.match.warning ?? "",
            isPresented: Binding(get: { warning != nil }, set: { if !$0 { warning = nil } }),
            presenting: warning
        ) { warning in
            Button("Use \(warning.match.spelling)") { onName(warning.gym, warning.match.spelling) }
            // The cancel role, so dismissing it keeps what you typed: a warning, not a gate.
            Button("Keep “\(warning.match.typed)”", role: .cancel) {
                onName(warning.gym, warning.match.typed)
            }
        }
    }

    private func named(_ gym: Gym, _ name: String) {
        if let match = check(gym, name) {
            warning = Warning(gym: gym, match: match)
        } else {
            onName(gym, name)
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { gym != nil }, set: { if !$0 { gym = nil } })
    }
}

extension View {
    /// Puts `Name this machine` over this view for the gym `gym` holds, and hands back
    /// the answer. `check` is the door's near-name check (SPEC §13.11); a door that has
    /// none — every lift's — leaves it out.
    func namingMachine(
        at gym: Binding<Gym?>,
        check: @escaping (Gym, String?) -> ErgModelMatch? = { _, _ in nil },
        onName: @escaping (Gym, String?) -> Void
    ) -> some View {
        modifier(MachineNamingAlert(gym: gym, check: check, onName: onName))
    }
}
