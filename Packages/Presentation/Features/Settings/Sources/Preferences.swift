// Preferences stored in UserDefaults. None of them is part of the synced data.
import Foundation
import SwiftUI

/// Appearance choice, stored by the app as its raw value.
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public static let storageKey = "appTheme"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Nil follows the macOS setting.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Text size for the whole app, stored by the app as its raw value. Every `appFont` size is
/// multiplied by `scale`.
public enum TextSize: String, CaseIterable, Identifiable, Sendable {
    case small
    case standard
    case large
    case extraLarge

    public static let storageKey = "textSize"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .small: "Small"
        case .standard: "Default"
        case .large: "Large"
        case .extraLarge: "Extra large"
        }
    }

    public var scale: CGFloat {
        switch self {
        case .small: 0.9
        case .standard: 1
        case .large: 1.15
        case .extraLarge: 1.3
        }
    }

    /// The next size up, or nil at the largest (View > Bigger Text).
    public var larger: TextSize? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    /// The next size down, or nil at the smallest (View > Smaller Text).
    public var smaller: TextSize? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index > 0 else { return nil }
        return all[index - 1]
    }
}

/// What Settings > About shows.
public struct AboutInfo: Sendable, Equatable {
    public let version: String
    public let code: String
    public let isDevelopmentBuild: Bool

    public init(version: String, code: String, isDevelopmentBuild: Bool) {
        self.version = version
        self.code = code
        self.isDevelopmentBuild = isDevelopmentBuild
    }

    public static func load(from bundle: Bundle = .main) -> AboutInfo {
        AboutInfo(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            code: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
            isDevelopmentBuild: bundle.bundleIdentifier?.hasSuffix(".dev") ?? false
        )
    }
}
