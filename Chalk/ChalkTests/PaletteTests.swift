import Testing
import UIKit

@testable import Chalk

/// Chalk's palette (SPEC §15.4): monochrome white or black with one cool grey, and the
/// goal kept orange. The values are the identity prototype's tokens
/// (`docs/prototypes/identity/README.md`, *The tokens*).
@Suite("Palette")
struct PaletteTests {

    @Test("Each colour asset resolves to its token in light and dark", arguments: [
        ("AccentColor", 0x000000, 0xFFFFFF),
        ("Ground", 0xFFFFFF, 0x000000),
        ("OnAccent", 0xFFFFFF, 0x000000),
        ("Grey", 0xA2A7AC, 0x8A8F96),
        ("Goal", 0xFF9500, 0xFF9F0A),
    ])
    func eachAssetResolvesToItsToken(name: String, light: Int, dark: Int) throws {
        let color = try #require(UIColor(named: name, in: .main, compatibleWith: nil))

        #expect(Self.hex(color, .light) == light)
        #expect(Self.hex(color, .dark) == dark)
    }

    private static func hex(_ color: UIColor, _ style: UIUserInterfaceStyle) -> Int {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ c: CGFloat) -> Int { Int((c * 255).rounded()) }
        return byte(r) << 16 | byte(g) << 8 | byte(b)
    }
}
