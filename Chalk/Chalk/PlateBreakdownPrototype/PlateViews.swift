import SwiftUI

// PROTOTYPE — three ways a plate breakdown reads under variant E's readout (#141), and
// *Off*, the screen as it is today, which is what cutting it looks like.

enum PlateVariant: String, CaseIterable {
    case off = "0", line = "A", row = "B", sleeve = "C"

    var name: String {
        switch self {
        case .off: "Off (cut)"
        case .line: "Line under the number"
        case .row: "A row under the chart"
        case .sleeve: "Plates drawn"
        }
    }
}

/// The prototype's switches, read by the real detail screen. Set by the root's bar and the
/// overflow's *Bar* menu.
enum PlateProto {
    static var variant: PlateVariant {
        PlateVariant(rawValue: UserDefaults.standard.string(forKey: "prototype.plates") ?? "") ?? .line
    }

    static var unit: ProtoWeightUnit {
        ProtoWeightUnit(rawValue: UserDefaults.standard.string(forKey: "prototype.unit") ?? "") ?? .kg
    }
}

private extension Array where Element == Double {
    var platesText: String { map(\.plateText).joined(separator: " · ") }
}

/// A: one grey line between the number and the goal line, as the subhead once was.
struct PlateLine: View {
    let breakdown: PlateBreakdown
    let unit: ProtoWeightUnit
    let bar: Double

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.2), value: text)
    }

    private var text: String {
        switch breakdown {
        case .bar:
            "Just the bar"
        case .belowBar:
            "Less than the \(bar.plateText) \(unit.rawValue) bar"
        case .plates(let plates, let loads, let exact):
            if plates.isEmpty {
                "\(loads.plateText) \(unit.rawValue) loads: just the bar"
            } else if exact {
                "\(plates.platesText) a side"
            } else {
                "\(loads.plateText) \(unit.rawValue) loads: \(plates.platesText) a side"
            }
        }
    }
}

/// B: a label-and-value row, first under the chart, in the identity's row idiom.
struct PlateRow: View {
    let breakdown: PlateBreakdown
    let unit: ProtoWeightUnit
    let bar: Double

    var body: some View {
        FactRow(label: label, value: value)
    }

    private var label: String {
        switch breakdown {
        case .plates(_, let loads, false): "Plates for \(loads.plateText) \(unit.rawValue)"
        default: "Plates a side"
        }
    }

    private var value: String {
        switch breakdown {
        case .bar: "Just the bar"
        case .belowBar: "Under the bar"
        case .plates(let plates, _, _): plates.isEmpty ? "Just the bar" : plates.platesText
        }
    }
}

/// C: the plates drawn as they sit on one sleeve, biggest nearest the collar, each with its
/// number in it. The weight they make follows in grey only when it is not the one read.
struct PlateSleeve: View {
    let breakdown: PlateBreakdown
    let unit: ProtoWeightUnit
    let bar: Double

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .center, spacing: 2) {
                // The bar's end and its collar.
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.secondary)
                    .frame(width: 14, height: 5)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.secondary)
                    .frame(width: 5, height: 16)
                ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                    plateView(plate)
                }
                // The rest of the sleeve, empty.
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.secondary)
                    .frame(width: 18, height: 5)
            }
            .animation(.snappy(duration: 0.25), value: plates)
            if let note {
                Text(note)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(height: 54)
    }

    private var plates: [Double] {
        if case .plates(let plates, _, _) = breakdown { return plates }
        return []
    }

    private var note: String? {
        switch breakdown {
        case .bar: "Just the bar"
        case .belowBar: "Under the bar"
        case .plates(let plates, let loads, let exact):
            plates.isEmpty ? "Just the bar" : exact ? nil : "loads \(loads.plateText) \(unit.rawValue)"
        }
    }

    private func plateView(_ plate: Double) -> some View {
        let biggest = unit.plates.first!
        let height = 22 + 32 * (plate / biggest).squareRoot()
        return RoundedRectangle(cornerRadius: 4)
            .fill(Palette.current.accent)
            .frame(width: 30, height: height)
            .overlay {
                Text(plate.plateText)
                    .font(.system(size: plate < 10 ? 10 : 12, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(Palette.current.onAccent)
                    .padding(.horizontal, 1)
            }
    }
}
