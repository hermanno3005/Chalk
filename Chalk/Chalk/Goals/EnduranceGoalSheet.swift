import SwiftUI

/// The endurance goal sheet (SPEC §13.10): **a short form, not the two-stage giant
/// number** — the zone segmented, then duration, incline on a speed erg, and intensity as
/// rows typed on the lap-list grid's keypad. It commits with `Set goal`, never `Save`, so
/// it cannot be mistaken for logging a block.
///
/// One live line under the intensity, in the goal colour and grey where the number is one
/// you already hold. `Clear goal` at the foot, only with a goal, with no confirmation.
struct EnduranceGoalSheet: View {
    /// Held for the life of the presentation, as the lap-list sheet holds its own.
    @State var model: EnduranceGoalSheetModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Zone", selection: $model.zone) {
                    ForEach(ZoneLine.zones, id: \.self) { zone in
                        Text("Z\(zone)").tag(Int?.some(zone))
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 0) {
                    ForEach(model.rows, id: \.self) { field in
                        row(field)
                        if field != model.rows.last { Divider() }
                    }
                }
                .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 10))

                Text(model.line?.text ?? " ")
                    .font(.subheadline)
                    .foregroundStyle(Color.goal(reached: model.line?.isReached == true))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 22)
                    .animation(.snappy(duration: 0.2), value: model.line)

                Spacer(minLength: 0)
                NumberKeypad(decimalIsDead: model.decimalIsDead) { key in
                    withAnimation(.snappy(duration: 0.15)) { model.type(key) }
                }
                if model.hasGoal {
                    Button("Clear goal", role: .destructive) {
                        model.clearGoal()
                        dismiss()
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .navigationTitle(model.hasGoal ? "Change goal" : "Set a goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set goal") {
                        model.setGoal()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!model.canSetGoal)
                }
            }
        }
    }

    /// One row: the field's name, its value as typed, and — on the row the keypad types
    /// into — the accent outline the grid's focused cell carries.
    private func row(_ field: EnduranceField) -> some View {
        let isFocused = model.focus == field
        return Button {
            model.select(field)
        } label: {
            HStack {
                Text(field.name(model.unit))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(model.text(field).isEmpty ? "—" : model.text(field) + suffix(field))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(model.text(field).isEmpty ? .tertiary : .primary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 2)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    private func suffix(_ field: EnduranceField) -> String {
        switch field {
        case .incline: " %"
        // A level's row is already named `Level`.
        case .intensity: model.unit == .level ? "" : " " + field.columnTitle(model.unit)
        default: ""
        }
    }
}
