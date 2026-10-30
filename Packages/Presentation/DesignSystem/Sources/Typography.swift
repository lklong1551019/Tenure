import SwiftUI

extension EnvironmentValues {
    /// Multiplier for every `appFont` size, from the text size setting. 1 is the designed size.
    @Entry public var textScale: CGFloat = 1
}

extension View {
    /// The system font at `size` points times the text size setting.
    public func appFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(AppFont(size: size, weight: weight, design: design))
    }
}

private struct AppFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    @Environment(\.textScale) private var scale

    func body(content: Content) -> some View {
        content.font(.system(size: (size * scale).rounded(), weight: weight, design: design))
    }
}
