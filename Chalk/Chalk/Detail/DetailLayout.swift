import SwiftUI

// The pieces both detail screens are laid out from (SPEC §5.1, §13.8), as Trade
// Republic's stock screen (§15.4, `docs/prototypes/identity/`): the name in grey over the
// number with its aside, the zones as text tabs, the chart bled off the leading edge,
// and the rest of the readout in label-and-value rows.

/// The top of a detail screen: the name in grey — **the screen's only title** — then
/// the big number, bold with its unit at the same size, and a small bold aside beside it:
/// `102,5 kg × 5`, `15.0 km/h 6:00 in Z4`.
///
/// Without a number (nothing logged, zones not set) it is the name alone. A number that
/// is not there — an unproven cell, a zone with no line — is a dimmed `—` rather than a
/// number from somewhere else (SPEC §4).
struct DetailHead: View {
    let name: String
    var number: String?
    var aside: String?
    var dimmed = false

    /// 40 pt at the default size, scaling with the large title (§15.4).
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 40
    @ScaledMetric(relativeTo: .title3) private var asideSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let number {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(number)
                        .font(.system(size: numberSize, weight: .bold))
                        .tracking(-0.8)
                        .monospacedDigit()
                        // The number moves digit by digit as the thumb crosses the
                        // chart, rather than cross-fading whole.
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: number)
                        .foregroundStyle(dimmed ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    if let aside {
                        Text(aside)
                            .font(.system(size: asideSize, weight: .bold))
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One fact under the chart: the label in grey, the value bold at the trailing end, at
/// least 45 pt tall and no divider. **A row that opens a sheet carries a grey `›` after
/// its label**; one with no `action` is plain text and not a button.
struct FactRow: View {
    let label: String
    let value: String
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { content(opens: true) }
                .buttonStyle(.plain)
        } else {
            content(opens: false)
                .accessibilityElement(children: .combine)
        }
    }

    private func content(opens: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
            if opens {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .font(.callout)
        .frame(minHeight: 45)
        .contentShape(.rect)
    }
}

/// `Z1`–`Z5` as text, grey off and the primary on, with no fill (SPEC §13.8). **A zone
/// with no line is dimmed but still tappable**: you see where you have never landed, and
/// can still ask.
struct ZoneTabs: View {
    let selected: Int
    let hasLine: (Int) -> Bool
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ZoneLine.zones, id: \.self) { zone in
                Button {
                    onSelect(zone)
                } label: {
                    Text("Z\(zone)")
                        .font(.callout)
                        .foregroundStyle(style(zone))
                        .frame(width: 52, height: 32, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(zone == selected ? .isSelected : [])
            }
        }
    }

    private func style(_ zone: Int) -> AnyShapeStyle {
        if zone == selected { return AnyShapeStyle(.primary) }
        return hasLine(zone) ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary)
    }
}

extension View {
    /// A detail screen's chart: **the one thing on the screen that gives way**, from 210
    /// down to 110 pt, so the screen does not scroll while it fits (SPEC §15.4). It is
    /// offered space ahead of the empty space under the rows, so it takes its full height
    /// whenever there is room, and it bleeds off the leading edge to the trailing margin.
    func detailChart() -> some View {
        frame(minHeight: 110, maxHeight: 210)
            .layoutPriority(1)
            .padding(.leading, -16)
    }
}
