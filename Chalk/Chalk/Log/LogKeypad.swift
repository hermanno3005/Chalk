import SwiftUI

/// The keypad, for jumps (SPEC §6.2). Same control on both stages, with the **decimal
/// key dead on the reps stage** — present and inert rather than missing, so the keys do
/// not move under your thumb between stages.
struct LogKeypad: View {
    let decimalIsDead: Bool
    let onKey: (LogSheetModel.Key) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(1...9, id: \.self) { digit in
                key(String(digit), .digit(digit))
            }
            key(WeightText.decimalSeparator, .decimal, accessibilityLabel: "Decimal point")
                .disabled(decimalIsDead)
            key("0", .digit(0))
            key(nil, .delete, symbol: "delete.backward", accessibilityLabel: "Delete")
        }
    }

    private func key(
        _ title: String?,
        _ pressed: LogSheetModel.Key,
        symbol: String? = nil,
        accessibilityLabel: String? = nil
    ) -> some View {
        Button {
            onKey(pressed)
        } label: {
            Group {
                if let symbol {
                    Image(systemName: symbol)
                } else {
                    Text(title ?? "")
                }
            }
            .font(.title2.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .accessibilityLabel(accessibilityLabel ?? title ?? "")
    }
}
