import AppKit
import SwiftUI

/// Color tokens from the design mocks (Tenure redesign canvas), each with a dark-mode counterpart.
public enum Palette {
    /// Window ground behind cards.
    public static let ground = dynamic(light: 0xF7F8FA, dark: 0x16181B)
    public static let sidebar = dynamic(light: 0xEEF1F4, dark: 0x1C1F23)
    /// Cards, the detail pane, fields.
    public static let surface = dynamic(light: 0xFFFFFF, dark: 0x23272C)
    /// Wells inside a surface: metric tiles, meta chips.
    public static let sunken = dynamic(light: 0xF3F5F8, dark: 0x1A1D21)
    public static let border = dynamic(light: 0xE3E7EC, dark: 0x30353C)
    /// Outlines of controls, a step stronger than dividers.
    public static let borderStrong = dynamic(light: 0xD3D9E0, dark: 0x3E444C)
    public static let ink = dynamic(light: 0x111827, dark: 0xF3F4F6)
    public static let secondaryInk = dynamic(light: 0x374151, dark: 0xD1D5DB)
    public static let mutedInk = dynamic(light: 0x6B7280, dark: 0x9CA3AF)
    public static let accent = dynamic(light: 0x0F766E, dark: 0x2DD4BF)
    public static let accentSoft = dynamic(light: 0xE3F4F1, dark: 0x123A35)
    public static let accentInk = dynamic(light: 0x0B5D56, dark: 0x7EE8D6)
    /// Text and icons on `accent`.
    public static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x042F2A)
    public static let success = dynamic(light: 0x15803D, dark: 0x86EFAC)
    public static let successSoft = dynamic(light: 0xDCFCE7, dark: 0x14321F)
    public static let warning = dynamic(light: 0x92400E, dark: 0xFCD34D)
    public static let warningSoft = dynamic(light: 0xFEF3C7, dark: 0x3A2E12)
    public static let danger = dynamic(light: 0xB91C1C, dark: 0xFCA5A5)
    public static let dangerSoft = dynamic(light: 0xFEE2E2, dark: 0x3F1D1D)
    public static let violet = dynamic(light: 0x6D28D9, dark: 0xC4B5FD)
    public static let violetSoft = dynamic(light: 0xEDE9FE, dark: 0x2E2650)
    public static let blue = dynamic(light: 0x1D4ED8, dark: 0x93C5FD)
    public static let blueSoft = dynamic(light: 0xDBEAFE, dark: 0x1B2A47)
    public static let teal = dynamic(light: 0x0F766E, dark: 0x5EEAD4)
    public static let tealSoft = dynamic(light: 0xE3F4F1, dark: 0x123A35)
    /// Card shadow; stronger in dark, where the border carries less.
    public static let shadow = dynamic(light: 0x111827, dark: 0x000000, lightAlpha: 0.07, darkAlpha: 0.35)

    private static func dynamic(
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return NSColor(hex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
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
    fileprivate convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension View {
    /// White card on the ground, hairline border, 12 pt corners.
    public func cardSurface(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadius).strokeBorder(Palette.border))
    }

    /// Soft lift for cards that sit on the ground.
    public func cardShadow() -> some View {
        self.shadow(color: Palette.shadow, radius: 2, x: 0, y: 1)
    }

    /// Text field chrome matching the mocks.
    public func fieldChrome() -> some View {
        self.textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: Metrics.controlHeight)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: Metrics.controlRadius).strokeBorder(Palette.borderStrong))
    }
}
