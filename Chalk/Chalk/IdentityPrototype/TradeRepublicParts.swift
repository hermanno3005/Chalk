import SwiftUI

// PROTOTYPE — the pieces round two borrows from Trade Republic's app (#140), measured
// off its App Store screenshots: text tabs like its `1T 1W 1M 1J Max` range picker, and
// label-and-value rows like its interest screen. Throwaway, as the rest of this folder.

/// Plain text tabs: grey when off, black when on, no fill and no pill. About 52 pt apart
/// in Trade Republic's range picker; Chalk's five zones fit at that pitch.
struct TextTabs: View {
    let titles: [String]
    let selected: Int
    /// A tab with nothing behind it is dimmed but still tappable, as a zone with no line is.
    let isLive: (Int) -> Bool
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(titles.indices, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Text(titles[index])
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            index == selected ? AnyShapeStyle(.primary)
                                : isLive(index) ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary)
                        )
                        .frame(width: 52, height: 32, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(index == selected ? .isSelected : [])
            }
        }
    }
}

/// One row of facts: grey label left, black bold value right, ~45 pt pitch, no divider.
/// A row that opens something carries a grey `›` after its label, as Trade Republic's do.
struct FactRow: View {
    let label: String
    let value: String
    var opens = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .foregroundStyle(.secondary)
                if opens {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Text(value)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(minHeight: 45)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Not `.disabled`, which would grey the value too.
        .allowsHitTesting(action != nil)
    }
}

/// Trade Republic's head: a grey name, then the number with a small bold aside beside it
/// where they put `▲ 10,55 %`.
struct NamedNumber: View {
    let name: String
    let number: String
    let aside: String?
    let dimmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                BigNumber(text: number, dimmed: dimmed)
                if let aside {
                    Text(aside)
                        .font(.system(size: 18, weight: .bold))
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Round two's type and greys over a whole screen: semibold by default, and
    /// `.secondary` resolving to Trade Republic's cool grey rather than the system's.
    @ViewBuilder
    func tradeRepublicText() -> some View {
        let palette = Palette.current
        if palette.isTradeRepublic, let grey = palette.secondaryText {
            self
                .fontWeight(.semibold)
                .foregroundStyle(.primary, grey, grey.opacity(0.45))
        } else {
            self
        }
    }
}
