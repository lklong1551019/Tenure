import SwiftUI

public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(13, weight: .semibold)
            .foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 18)
            .frame(minHeight: Metrics.controlHeight)
            .background(
                Palette.accent.opacity(configuration.isPressed ? 0.85 : 1),
                in: RoundedRectangle(cornerRadius: Metrics.controlRadius)
            )
            .contentShape(Rectangle())
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(13, weight: .medium)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: Metrics.controlHeight)
            .background(
                configuration.isPressed ? Palette.sidebar : Palette.surface,
                in: RoundedRectangle(cornerRadius: Metrics.controlRadius)
            )
            .overlay(RoundedRectangle(cornerRadius: Metrics.controlRadius).strokeBorder(Palette.borderStrong))
            .contentShape(Rectangle())
    }
}

/// Inline error line with an alert icon.
public struct ErrorLine: View {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .appFont(12)
            .foregroundStyle(Palette.danger)
    }
}

/// Small semibold label above a control, as in every form in the mocks.
public struct LabeledField<Control: View>: View {
    private let label: String
    private let control: Control

    public init(_ label: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .appFont(12, weight: .semibold)
                .foregroundStyle(Palette.secondaryInk)
            control
        }
    }
}

/// A key or key combination as printed on a keyboard, such as "⌘K".
public struct KeyCap: View {
    private let keys: String

    public init(_ keys: String) {
        self.keys = keys
    }

    public var body: some View {
        Text(keys)
            .appFont(11, weight: .medium, design: .rounded)
            .foregroundStyle(Palette.secondaryInk)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.border))
            .fixedSize()
    }
}

extension Binding where Value == Bool {
    /// True while `item` holds a value; setting false clears it. For sheets, dialogs, and
    /// file panels driven by an optional.
    public init<Item>(present item: Binding<Item?>) {
        self.init(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } })
    }
}
