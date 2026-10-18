import SwiftUI

extension View {
    /// `Change kind` on the erg detail screen (SPEC §8, §13.11): set `isRequested` from
    /// the overflow item and this puts up whichever of the two the flip needs.
    func changingKind(of model: ErgDetailModel, isRequested: Binding<Bool>) -> some View {
        modifier(ErgChangeKind(model: model, isRequested: isRequested))
    }
}

/// The two faces of an erg's kind change, as on a lift's detail screen: *Which machine is
/// this on?* where there are intervals to place, and one confirmation otherwise — pooling,
/// which names the consequence out loud, or the flip with nothing logged.
private struct ErgChangeKind: ViewModifier {
    let model: ErgDetailModel
    @Binding var isRequested: Bool

    @State private var askingForMachine = false
    @State private var confirming = false

    func body(content: Content) -> some View {
        content
            // Decided at the tap, not re-read while presented: the flip itself turns
            // the direction round, and with it which face would be asked.
            .onChange(of: isRequested) { _, requested in
                guard requested else { return }
                isRequested = false
                if model.kindChange.needsAMachine {
                    askingForMachine = true
                } else {
                    confirming = true
                }
            }
            // Answering it is the whole decision; there is no second confirmation. A
            // transferable erg has no machines to pick between, so this asks for a gym
            // and a name, as strength's does.
            .sheet(isPresented: $askingForMachine) {
                ChangeKindSheet(change: model.kindChange, gyms: model.gyms) { gym, name in
                    model.makeGymBound(at: gym, named: name)
                }
            }
            .confirmationDialog(
                model.kindChange.question,
                isPresented: $confirming,
                titleVisibility: .visible
            ) {
                // Destructive one way only: pooling hard-deletes the machine rows.
                Button(
                    model.kindChange.confirmButton,
                    role: model.isGymBound ? .destructive : nil
                ) {
                    if model.isGymBound {
                        model.makeTransferable()
                    } else {
                        model.makeGymBound()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(model.kindChange.detail)
            }
    }
}
