import DesignSystem
import Domain
import SwiftUI

/// The year menu at the head of the filter row: "All years" or one year, each with how many
/// of the board's tasks fall in it. Tinted while a year is chosen, like a kind chip that is on.
struct YearFilterChip: View {
    let years: [YearCount]
    /// Tasks on the board in every year, for the "All years" row.
    let total: Int
    @Binding var year: Int?
    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(year.map { String($0) } ?? "All years")
                    .appFont(13, weight: year == nil ? .medium : .semibold)
                Image(systemName: "chevron.down")
                    .imageScale(.small)
            }
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .foregroundStyle(year == nil ? Palette.secondaryInk : Tint.teal.foreground)
            .background(year == nil ? Palette.surface : Tint.teal.background, in: Capsule())
            .overlay(
                Capsule().strokeBorder(year == nil ? Palette.borderStrong : Tint.teal.foreground.opacity(0.45))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(years.isEmpty)
        .help("Show one year's tasks")
        .accessibilityLabel(year.map { "Year \($0)" } ?? "All years")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            menu
        }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 2) {
            row("All years", count: total, isOn: year == nil) { year = nil }
            Divider()
                .padding(.vertical, 4)
            ForEach(years, id: \.year) { item in
                row(String(item.year), count: item.count, isOn: year == item.year) { year = item.year }
            }
        }
        .padding(6)
        .frame(width: 220)
    }

    private func row(_ title: String, count: Int, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            isOpen = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .opacity(isOn ? 1 : 0)
                    .accessibilityHidden(!isOn)
                Text(title)
                    .appFont(13, weight: isOn ? .semibold : .regular)
                Spacer()
                Text(count.counted("task"))
                    .appFont(12)
                    .foregroundStyle(isOn ? Palette.onAccent : Palette.mutedInk)
                    .monospacedDigit()
            }
            .foregroundStyle(isOn ? Palette.onAccent : Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isOn ? Palette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
