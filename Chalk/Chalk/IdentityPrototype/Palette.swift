import SwiftUI
import UIKit

// PROTOTYPE — the identity the real detail screens draw in while this prototype is
// checked out (#140). Throwaway: it lives at the `prototype-identity` tag, never on main.
//
// Three palettes taken from the chalk icon (`docs/app-icon.svg`: chalk faces #FBFAF6,
// #E2DFD7, #C4C0B6 on a slate ground #2C2D33 → #16171A). Each gives a ground, an accent,
// the goal colour, the zones' colours and a treatment for the readout's big number, in
// light and dark. The real views read `Palette.current` where they read `accentColor`
// and `Goal` on main.

enum IdentityVariant: String, CaseIterable {
    case a = "A", b = "B", c = "C"

    var name: String {
        switch self {
        case .a: "Chalk on slate"
        case .b: "Chalk bag"
        case .c: "Cue chalk"
        }
    }

    var palette: Palette {
        switch self {
        case .a: .slate
        case .b: .chalkBag
        case .c: .cueChalk
        }
    }
}

struct Palette {
    /// The screen's background.
    let ground: Color
    /// The curve, the zone line, the selected zone, the Log bar and the toolbar tint.
    let accent: Color
    /// Text on an accent fill.
    let onAccent: Color
    /// The goal colour (`Goal.colorset` on main): the donut and the goal line.
    let goal: Color
    /// Z1…Z5. Nil: the zones take no colour of their own and draw in the accent.
    let zones: [Color]?
    let number: NumberTreatment
    /// Whether the big number is drawn in the accent rather than in the primary label.
    let numberInAccent: Bool

    nonisolated(unsafe) static var current = Palette.slate

    func zone(_ zone: Int) -> Color {
        zones?[zone - 1] ?? accent
    }

    /// Readable text on a zone's fill: dark on a light zone, white on a deep one.
    func onZone(_ zone: Int) -> Color {
        guard zones != nil else { return onAccent }
        return Color(UIColor { trait in
            let fill = UIColor(self.zone(zone)).resolvedColor(with: trait)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            fill.getRed(&r, green: &g, blue: &b, alpha: &a)
            let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            return luminance > 0.6 ? UIColor(hex: 0x16171A) : .white
        })
    }
}

enum NumberTreatment {
    /// Heavy rounded figures with chalk grain knocked out of them.
    case chalkGrain
    /// Black compressed figures, tall like a scoreboard, with a small capitalised unit.
    case compressed
    /// Bold serif figures with a quiet italic unit.
    case serif
}

extension Palette {
    /// **A — Chalk on slate.** The icon itself: warm chalk on slate, no hue at all. The
    /// accent is ink in light and chalk in dark; the goal is yellow chalk, the only
    /// colour on the screen. The zones take no colour.
    static let slate = Palette(
        ground: .proto(light: 0xF2F0EA, dark: 0x1A1B1F),
        accent: .proto(light: 0x2C2D33, dark: 0xECE8DF),
        onAccent: .proto(light: 0xFBFAF6, dark: 0x1A1B1F),
        goal: .proto(light: 0xB7791F, dark: 0xF0C24B),
        zones: nil,
        number: .chalkGrain,
        numberInAccent: true
    )

    /// **B — Chalk bag.** The icon's chalk on its own faces, and one hot colour, ember,
    /// like a climber's chalk bag. Ember is also Z4: the zones run warm from chalk grey
    /// to deep red. The goal moves to teal, the one cool thing on the screen.
    static let chalkBag = Palette(
        ground: .proto(light: 0xFBFAF6, dark: 0x16171A),
        accent: .proto(light: 0xD9480F, dark: 0xFF6A3D),
        onAccent: .white,
        goal: .proto(light: 0x0B7A75, dark: 0x2EC4B6),
        zones: [
            .proto(light: 0x8D8A83, dark: 0xA7A39A),
            .proto(light: 0xC9A227, dark: 0xE3BC3F),
            .proto(light: 0xE07B1F, dark: 0xFF9233),
            .proto(light: 0xD9480F, dark: 0xFF6A3D),
            .proto(light: 0xA61E1E, dark: 0xE5383B),
        ],
        number: .compressed,
        numberInAccent: false
    )

    /// **C — Cue chalk.** The blue of billiard chalk over a cool slate ground. The zones
    /// are one blue, pale to deep (bright in dark), so the hardest zone is the strongest
    /// blue. The goal stays orange, as it is on main.
    static let cueChalk = Palette(
        ground: .proto(light: 0xEEF2F7, dark: 0x12151B),
        accent: .proto(light: 0x1F5FBF, dark: 0x6AA6FF),
        onAccent: .proto(light: 0xFFFFFF, dark: 0x0E1A2E),
        goal: .proto(light: 0xE07800, dark: 0xFF9F0A),
        zones: [
            .proto(light: 0xA9C1E6, dark: 0x3E5274),
            .proto(light: 0x7FA6E0, dark: 0x4C78BC),
            .proto(light: 0x4F86D6, dark: 0x5A93E8),
            .proto(light: 0x1F5FBF, dark: 0x6AA6FF),
            .proto(light: 0x123B80, dark: 0xA9CBFF),
        ],
        number: .serif,
        numberInAccent: false
    )
}

/// The readout's big number in the variant's treatment: `52.5 kg`, `15.0 km/h`, or a dash
/// for an unproven cell. The unit is whatever follows the last space.
struct BigNumber: View {
    let text: String
    let dimmed: Bool

    private var palette: Palette { Palette.current }

    var body: some View {
        let parts = split
        HStack(alignment: .firstTextBaseline, spacing: unitSpacing) {
            figures(parts.number)
            if let unit = parts.unit {
                Text(palette.number == .compressed ? unit.uppercased() : unit)
                    .font(unitFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func figures(_ number: String) -> some View {
        let text = Text(number).font(numberFont).monospacedDigit()
        switch palette.number {
        case .chalkGrain:
            text
                .foregroundStyle(numberStyle)
                // The grain is the ground showing through, knocked out of the figures.
                .overlay {
                    ChalkGrain(color: palette.ground)
                        .mask { text }
                        .allowsHitTesting(false)
                }
                .contentTransition(.numericText())
        case .compressed, .serif:
            text
                .foregroundStyle(numberStyle)
                .contentTransition(.numericText())
        }
    }

    private var numberStyle: AnyShapeStyle {
        if dimmed { return AnyShapeStyle(.tertiary) }
        return palette.numberInAccent ? AnyShapeStyle(palette.accent) : AnyShapeStyle(.primary)
    }

    private var numberFont: Font {
        switch palette.number {
        case .chalkGrain: .system(size: 52, weight: .heavy, design: .rounded)
        case .compressed: .system(size: 72, weight: .black).width(.compressed)
        case .serif: .system(size: 50, weight: .bold, design: .serif)
        }
    }

    private var unitFont: Font {
        switch palette.number {
        case .chalkGrain: .system(size: 24, weight: .bold, design: .rounded)
        case .compressed: .system(size: 22, weight: .heavy).width(.compressed)
        case .serif: .system(size: 24, weight: .regular, design: .serif).italic()
        }
    }

    private var unitSpacing: CGFloat {
        palette.number == .compressed ? 6 : 5
    }

    private var split: (number: String, unit: String?) {
        guard let space = text.lastIndex(of: " ") else { return (text, nil) }
        return (String(text[..<space]), String(text[text.index(after: space)...]))
    }
}

/// Specks and short drag-marks in the ground colour, scattered the same way every time,
/// so a number looks written in chalk rather than printed.
private struct ChalkGrain: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
            func next() -> CGFloat {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
            }
            let specks = Int(size.width * size.height / 26)
            for _ in 0..<specks {
                let x = next() * size.width, y = next() * size.height
                let d = 0.5 + next() * 0.9
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(color.opacity(0.7)))
            }
            // Drag-marks run slightly uphill, as a stick of chalk skips across a board.
            for _ in 0..<Int(size.height * 0.9) {
                let x = next() * size.width, y = next() * size.height
                let length = 4 + next() * 14
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + length, y: y - length * 0.18))
                context.stroke(path, with: .color(color.opacity(0.45)), lineWidth: 0.7)
            }
        }
    }
}

extension Color {
    static func proto(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
