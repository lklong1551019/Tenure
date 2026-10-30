import SwiftUI

/// Color family of a badge or tile. Features map their own kinds onto these.
public enum Tint: Sendable, Hashable {
    case neutral, blue, violet, teal, amber, red

    /// The color of a task kind, by its stored name, so every feature shows a kind alike.
    public static func kind(_ rawValue: String) -> Tint {
        switch rawValue {
        case "product": .violet
        case "dev": .blue
        case "bugFix": .red
        case "findings": .amber
        default: .neutral
        }
    }

    public var foreground: Color {
        switch self {
        case .neutral: Palette.secondaryInk
        case .blue: Palette.blue
        case .violet: Palette.violet
        case .teal: Palette.teal
        case .amber: Palette.warning
        case .red: Palette.danger
        }
    }

    public var background: Color {
        switch self {
        case .neutral: Palette.sidebar
        case .blue: Palette.blueSoft
        case .violet: Palette.violetSoft
        case .teal: Palette.tealSoft
        case .amber: Palette.warningSoft
        case .red: Palette.dangerSoft
        }
    }
}

/// Small rounded label, for a task's kind and for status.
public struct Badge: View {
    private let text: String
    private let tint: Tint

    public init(_ text: String, tint: Tint) {
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        Text(text)
            .appFont(12, weight: .semibold)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .foregroundStyle(tint.foreground)
            .background(tint.background, in: RoundedRectangle(cornerRadius: 6))
            .fixedSize()
    }
}

/// Toggleable capsule for a filter: a dot in the kind's color; tinted in that color while on.
public struct FilterChip: View {
    private let text: String
    private let tint: Tint
    private let isOn: Bool
    private let action: () -> Void

    public init(_ text: String, tint: Tint, isOn: Bool, action: @escaping () -> Void) {
        self.text = text
        self.tint = tint
        self.isOn = isOn
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle()
                    .fill(tint.foreground)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(text)
                    .appFont(13, weight: isOn ? .semibold : .medium)
                    .lineLimit(1)
            }
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .foregroundStyle(isOn ? tint.foreground : Palette.secondaryInk)
            .background(isOn ? tint.background : Palette.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? tint.foreground.opacity(0.45) : Palette.borderStrong))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Before and after of one number, the change between them, and how it was measured.
public struct MetricTile: View {
    private let label: String
    private let before: String?
    private let after: String
    private let change: String?
    private let note: String?

    public init(label: String, before: String?, after: String, change: String? = nil, note: String?) {
        self.label = label
        self.before = before
        self.after = after
        self.change = change
        self.note = note
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .appFont(12, weight: .medium)
                .foregroundStyle(Palette.secondaryInk)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let before, !before.isEmpty {
                    Text(before)
                        .appFont(14)
                        .strikethrough(color: Palette.mutedInk)
                        .foregroundStyle(Palette.mutedInk)
                        .accessibilityLabel("from \(before)")
                }
                Text(after)
                    .appFont(19, weight: .bold)
                    .foregroundStyle(Palette.ink)
                    .accessibilityLabel("to \(after)")
            }
            if let change {
                ChangePill(change)
            }
            if let note, !note.isEmpty {
                Text(note)
                    .appFont(12)
                    .foregroundStyle(Palette.mutedInk)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Palette.sunken, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.border))
        .accessibilityElement(children: .combine)
    }
}

/// A relative change such as "-44%", in green.
public struct ChangePill: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .appFont(12, weight: .semibold)
            .monospacedDigit()
            .foregroundStyle(Palette.success)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .background(Palette.successSoft, in: Capsule())
            .fixedSize()
    }
}

/// Dark pill at the bottom of the window.
public struct Toast: View {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        Label(message, systemImage: "checkmark")
            .appFont(13)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityAddTraits(.isStaticText)
    }
}
