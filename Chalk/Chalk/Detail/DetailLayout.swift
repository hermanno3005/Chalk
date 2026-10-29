import SwiftUI

// The pieces both detail screens are laid out from (SPEC §5.1, §13.8), as Trade
// Republic's stock screen (§15.4, `docs/prototypes/identity/`): the name in grey over the
// number with its aside, the zones as text tabs, the chart bled off the leading edge,
// and the rest of the readout in label-and-value rows.

/// The top of a detail screen: the name in grey — **the screen's only title** — then
/// the big number, bold with its unit at the same size, and a small bold aside beside it:
/// `102,5 kg × 5`, `15.0 km/h 6:00 in Z4`.
///
/// **Nothing in it is capped or truncated** (SPEC §15.4): the number scales with the large
/// title, about 70 pt at the largest size, and the aside wraps under it when the two
/// cannot share a line. The number is never shrunk to fit.
///
/// Without a number (nothing logged, zones not set) it is the name alone. A number that
/// is not there — an unproven cell, a zone with no line — is a dimmed `—` rather than a
/// number from somewhere else (SPEC §4).
struct DetailHead: View {
    let name: String
    var number: String?
    var aside: String?
    var dimmed = false
    /// Whether a tap on it opens the history sheet, which VoiceOver is told.
    var opensHistory = false

    /// 40 pt at the default size, scaling with the large title (§15.4).
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 40
    @ScaledMetric(relativeTo: .title3) private var asideSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let number {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        numberText(number)
                        asideText
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        numberText(number)
                        asideText
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(opensHistory ? [.isHeader, .isButton] : .isHeader)
        .accessibilityHint(opensHistory ? "Shows these entries" : "")
    }

    private func numberText(_ number: String) -> some View {
        Text(number)
            .font(.system(size: numberSize, weight: .bold))
            .tracking(-0.8)
            .monospacedDigit()
            // The number moves digit by digit as the thumb crosses the chart, rather
            // than cross-fading whole.
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.2), value: number)
            .foregroundStyle(dimmed ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
    }

    @ViewBuilder
    private var asideText: some View {
        if let aside {
            Text(aside)
                .font(.system(size: asideSize, weight: .bold))
                .monospacedDigit()
        }
    }
}

/// One fact under the chart (SPEC §5.1, §13.8): the label in grey, the value bold at the
/// trailing end, at least 45 pt tall and no divider. **A row that opens a sheet carries a grey `›` after
/// its label**; one with no `action` is plain text and not a button.
///
/// **At large text it stacks** (SPEC §15.4), label over value, grey over bold with its
/// `›`, when the two cannot share a line. Each row decides alone.
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                labelText(opens: opens)
                Spacer(minLength: 12)
                valueText
            }
            VStack(alignment: .leading, spacing: 2) {
                labelText(opens: opens)
                valueText
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
        .frame(minHeight: 45)
        .contentShape(.rect)
    }

    private func labelText(opens: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
            if opens {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var valueText: some View {
        // A row with nothing on its trailing end, `Set your heart-rate zones`, stacks
        // into its label alone.
        if !value.isEmpty {
            Text(value)
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }
}

/// `Z1`–`Z5` as text, grey off and the primary on, with no fill (SPEC §13.8). **A zone
/// with no line is dimmed but still tappable**: you see where you have never landed, and
/// can still ask.
///
/// **They stop growing at xxxLarge**, past which five do not fit the width beside the
/// incline menu, and show the Large Content Viewer on a long press instead (SPEC §15.4).
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
                        // On the label alone: the Large Content Viewer reads the
                        // button's own text size, which is what shows it.
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(style(zone))
                        .frame(width: 52, height: 32, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityShowsLargeContentViewer()
                .accessibilityAddTraits(zone == selected ? .isSelected : [])
            }
        }
    }

    private func style(_ zone: Int) -> AnyShapeStyle {
        if zone == selected { return AnyShapeStyle(.primary) }
        return hasLine(zone) ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary)
    }
}

extension String {
    /// This text with no line break after a `/`, so `km/h` and `6:00 /km` never wrap
    /// apart at a large text size (SPEC §15.4), as `doneKeepingUnits` keeps a tile's.
    var unbrokenAtSlashes: String {
        replacingOccurrences(of: "/", with: "/\u{2060}")
    }
}

/// A detail screen's body, which **never scrolls while it fits** (SPEC §15.4): first the
/// chart gives way, down to 110 pt, and only when the screen cannot fit with the chart at
/// 110 pt does it scroll — at any text size — **with the chart back at its full 210 pt**,
/// since space is no longer what it is short of. The Log bar is the screen's
/// `safeAreaInset`, outside this, so it stays pinned either way.
///
/// **Once it has scrolled it keeps scrolling** until the text size changes or the screen
/// closes. On a screen at the edge of fitting, a scrub that rewraps the aside would
/// otherwise flip it between the two mid-drag, dropping the scrub and jumping the chart.
struct DetailBody<Content: View>: View {
    @ViewBuilder let content: Content

    /// The branch `ViewThatFits` has on screen, as each reports from its frame — not
    /// `onAppear`, which fires on a branch it only measures.
    @State private var shown: Branch?
    @State private var scrolled = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Branch { case fits, scrolls }

    var body: some View {
        ViewThatFits(in: .vertical) {
            // Latched by refusing to fit rather than by swapping views, so latching
            // rebuilds nothing under a finger.
            content
                .frame(minHeight: scrolled ? .greatestFiniteMagnitude : nil)
                .onGeometryChange(for: Bool.self) { _ in true } action: { _ in shown = .fits }
            ScrollView {
                content
                    .environment(\.detailScrolls, true)
            }
            .onGeometryChange(for: Bool.self) { _ in true } action: { _ in shown = .scrolls }
        }
        // Only a scroll that holds latches: a screen's first layout passes can briefly
        // pick it on the way to fitting.
        .task(id: shown) {
            guard shown == .scrolls else { return }
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { scrolled = true }
        }
        .onChange(of: dynamicTypeSize) { scrolled = false }
    }
}

extension EnvironmentValues {
    /// Whether the detail screen around a chart scrolls, which fixes it at 210 pt.
    @Entry var detailScrolls = false
}

extension View {
    /// A detail screen's chart: **the one thing on the screen that gives way**, from 210
    /// down to 110 pt, so the screen does not scroll while it fits (SPEC §15.4). It is
    /// offered space ahead of the empty space under the rows, so it takes its full height
    /// whenever there is room, and it bleeds off the leading edge to the trailing margin.
    func detailChart() -> some View {
        modifier(DetailChart())
    }
}

private struct DetailChart: ViewModifier {
    @Environment(\.detailScrolls) private var scrolls

    func body(content: Content) -> some View {
        Group {
            if scrolls {
                content.frame(height: 210)
            } else {
                // An ideal of 110 pt is what `DetailBody` measures the screen against,
                // so it scrolls only when the chart at its smallest still does not fit.
                content
                    .frame(minHeight: 110, idealHeight: 110, maxHeight: 210)
                    .layoutPriority(1)
            }
        }
        .padding(.leading, -16)
    }
}
