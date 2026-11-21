import FileMintCore
import Foundation
import Testing

struct AppAccentPaletteTests {
    @Test("custom hex input accepts six sRGB digits and rejects incomplete or transparent colors")
    func customHexInput() {
        #expect(AppAccentColor.parseCustomRGB(" #ffEe19 ") == 0xFFEE19)
        #expect(AppAccentColor.parseCustomRGB("000000") == 0x000000)
        for invalid in ["#123", "+12345", "#00FF00FF", "#FF GG00", "##FFCC00", "#ＦＦＣＣ００"] {
            #expect(AppAccentColor.parseCustomRGB(invalid) == nil)
        }
    }

    @Test("light and dark accents keep foregrounds legible for saturated and neutral choices",
          arguments: [0x000000, 0xFFFFFF, 0xFFEE19, 0xFF0000, 0x00FF00, 0x0000FF, 0xA657D8, 0x3A8067] as [UInt32])
    func customAccentContrast(rgb: UInt32) {
        for dark in [false, true] {
            let palette = AppAccentPalette(rgb: rgb, dark: dark)
            #expect(contrast(palette.accent, palette.selection) >= 4.5)
            #expect(contrast(palette.accent, dark ? 0x2B302D : 0xF1F3EF) >= 4.5)
            #expect(contrast(palette.strong, palette.selection) >= 4.5)
            #expect(contrast(palette.onStrong, palette.strong) >= 4.5)
        }
    }

    @Test("a source that already contrasts is preserved in that appearance")
    func preserveLegibleSource() {
        #expect(AppAccentPalette(rgb: 0x285E9D, dark: false).accent == 0x285E9D)
        #expect(AppAccentPalette(rgb: 0xFFEE19, dark: true).accent == 0xFFEE19)
    }

    private func contrast(_ foreground: UInt32, _ background: UInt32) -> Double {
        func luminance(_ rgb: UInt32) -> Double {
            let channels = [rgb >> 16, (rgb >> 8) & 255, rgb & 255].map { Double($0) / 255 }
            let linear = channels.map { value in
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
        }
        let values = [luminance(foreground), luminance(background)].sorted()
        return (values[1] + 0.05) / (values[0] + 0.05)
    }
}
