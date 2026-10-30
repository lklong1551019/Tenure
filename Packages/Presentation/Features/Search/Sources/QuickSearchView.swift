import DesignSystem
import Domain
import SwiftUI

/// The Cmd+K palette, drawn over a dimmed window.
public struct QuickSearchView: View {
    @Bindable private var model: QuickSearchViewModel
    @FocusState private var isFocused: Bool

    public init(model: QuickSearchViewModel) {
        self.model = model
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture { model.close() }
                .accessibilityHidden(true)
            palette
                .frame(width: 640)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.border))
                .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
                .padding(.top, 72)
        }
        .task { await model.load() }
    }

    private var palette: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.secondaryInk)
                TextField("Search tasks, tags, links", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .onKeyPress(.downArrow) {
                        model.moveSelection(by: 1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        model.moveSelection(by: -1)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        model.close()
                        return .handled
                    }
                    .onKeyPress(.return, phases: .down) { press in
                        if press.modifiers.contains(.command) {
                            model.openSelectedLink()
                        } else {
                            model.showSelected()
                        }
                        return .handled
                    }
                keyCap("esc")
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            Divider()
            results
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                hint("Return", "Show the task on its board")
                hint("Command Return", "Open the task's link")
                hint("Up / Down", "Move the selection")
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var results: some View {
        VStack(spacing: 2) {
            if model.results.isEmpty {
                Text(model.query.isEmpty ? "No tasks yet." : "No tasks match.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.secondaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, entry in
                row(entry, isSelected: index == model.selectedIndex)
                    .onTapGesture(count: 2) { model.showSelected() }
                    .onTapGesture { model.select(entry) }
            }
        }
        .padding(8)
    }

    private func hint(_ key: String, _ action: String) -> some View {
        HStack(spacing: 8) {
            keyCap(key)
                .frame(width: 112, alignment: .leading)
            Text(action)
        }
    }

    private func keyCap(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 11))
            .foregroundStyle(Palette.mutedInk)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.border))
    }

    private func row(_ entry: Entry, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Badge(entry.type.title, tint: isSelected ? .neutral : entry.type.tint)
            Text(entry.name)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Text(isSelected ? "Return to show" : "\(model.boardName(of: entry)), \(entry.date.description)")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.white : Palette.mutedInk)
        }
        .foregroundStyle(isSelected ? Color.white : Palette.ink)
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(isSelected ? Palette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension EntryType {
    fileprivate var tint: Tint {
        switch self {
        case .product: .violet
        case .dev: .teal
        case .bugFix: .red
        case .findings: .amber
        default: .neutral
        }
    }
}
