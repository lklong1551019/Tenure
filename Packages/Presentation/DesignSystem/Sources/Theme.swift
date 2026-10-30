import AppKit
import SwiftUI

/// Color tokens from the design mocks, each with a dark-mode counterpart.
public enum Palette {
    public static let ground = dynamic(light: 0xF4F3EF, dark: 0x1E1E1C)
    public static let sidebar = dynamic(light: 0xECEAE4, dark: 0x262624)
    public static let surface = dynamic(light: 0xFFFFFF, dark: 0x2C2C2A)
    public static let border = dynamic(light: 0xDEDBD3, dark: 0x3A3936)
    public static let ink = dynamic(light: 0x1D1D1F, dark: 0xF2F1EC)
    public static let secondaryInk = dynamic(light: 0x5E5C57, dark: 0xB4B2A9)
    public static let mutedInk = dynamic(light: 0x6F6C66, dark: 0x9A978F)
    public static let accent = dynamic(light: 0x2457D6, dark: 0x6E95F2)
    public static let accentSoft = dynamic(light: 0xE7EDFB, dark: 0x22314F)
    public static let accentInk = dynamic(light: 0x1C47B3, dark: 0xA9C1F7)
    public static let success = dynamic(light: 0x1E6B3A, dark: 0x7DCB97)
    public static let successSoft = dynamic(light: 0xE3F1E7, dark: 0x1F3326)
    public static let warning = dynamic(light: 0x8A5300, dark: 0xF0B45C)
    public static let warningSoft = dynamic(light: 0xFBEFD9, dark: 0x3A2C14)
    public static let danger = dynamic(light: 0xA3261E, dark: 0xF28B82)
    public static let dangerSoft = dynamic(light: 0xFBE4E1, dark: 0x3D1E1B)
    public static let violet = dynamic(light: 0x4A3FA8, dark: 0xB9B2F2)
    public static let violetSoft = dynamic(light: 0xEEEDFE, dark: 0x2E2A52)
    public static let teal = dynamic(light: 0x0F6E56, dark: 0x7FD9BC)
    public static let tealSoft = dynamic(light: 0xE1F5EE, dark: 0x173A30)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(hex: isDark ? dark : light)
            }
        )
    }
}

public enum Metrics {
    public static let cornerRadius: CGFloat = 12
    public static let controlRadius: CGFloat = 8
    public static let controlHeight: CGFloat = 36
    public static let largeControlHeight: CGFloat = 44
}

extension NSColor {
    fileprivate convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension View {
    /// White card on the warm ground, hairline border, 12 pt corners.
    public func cardSurface(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadius).strokeBorder(Palette.border))
    }

    /// Text field chrome matching the mocks.
    public func fieldChrome() -> some View {
        self.textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: Metrics.controlHeight)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: Metrics.controlRadius).strokeBorder(Palette.border))
    }
}
