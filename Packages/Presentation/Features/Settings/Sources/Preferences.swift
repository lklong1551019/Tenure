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
