import SwiftUI

/// Color family of a badge or tile. Features map their own kinds onto these.
public enum Tint: Sendable, Hashable, CaseIterable {
    case neutral, blue, violet, teal, amber, red, green

    public var foreground: Color {
        switch self {
        case .neutral: Palette.secondaryInk
        case .blue: Palette.accentInk
        case .violet: Palette.violet
        case .teal: Palette.teal
        case .amber: Palette.warning
        case .red: Palette.danger
        case .green: Palette.success
        }
    }

    public var background: Color {
        switch self {
        case .neutral: Palette.sidebar
        case .blue: Palette.accentSoft
        case .violet: Palette.violetSoft
        case .teal: Palette.tealSoft
        case .amber: Palette.warningSoft
        case .red: Palette.dangerSoft
        case .green: Palette.successSoft
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
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tint.foreground)
            .background(tint.background, in: RoundedRectangle(cornerRadius: 6))
            .fixedSize()
    }
}

/// Toggleable capsule for a filter, tinted while on.
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
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundStyle(isOn ? tint.foreground : Palette.mutedInk)
                .background(isOn ? tint.background : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(isOn ? .clear : Palette.border))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Before and after of one number, with how it was measured.
public struct MetricTile: View {
    private let label: String
    private let before: String?
    private let after: String
    private let note: String?

    public init(label: String, before: String?, after: String, note: String?) {
        self.label = label
        self.before = before
        self.after = after
        self.note = note
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.secondaryInk)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let before, !before.isEmpty {
                    Text(before).foregroundStyle(Palette.mutedInk)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.mutedInk)
                        .accessibilityLabel("to")
                }
                Text(after).foregroundStyle(Palette.success)
            }
            .font(.system(size: 17, weight: .semibold))
            if let note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.mutedInk)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Palette.sidebar, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
        .accessibilityElement(children: .combine)
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
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityAddTraits(.isStaticText)
    }
}
