import DesignSystem
import SwiftUI

/// Every keyboard shortcut, from Help > Keyboard Shortcuts (Cmd-/) or the sidebar hint.
struct ShortcutsView: View {
    struct Shortcut: Hashable {
        let keys: String
        let action: String
    }

    static let groups: [(title: String, shortcuts: [Shortcut])] = [
        (
            "Tasks",
            [
                Shortcut(keys: "⌘N", action: "New task"),
                Shortcut(keys: "⇧⌘N", action: "New board"),
                Shortcut(keys: "Double-click", action: "Edit a task"),
                Shortcut(keys: "⇧⌘E", action: "Export the board as Markdown"),
                Shortcut(keys: "⇧⌘C", action: "Copy the selected task as Markdown"),
            ]
        ),
        (
            "Find",
            [
                Shortcut(keys: "⌘K", action: "Quick search across every board"),
                Shortcut(keys: "↩", action: "In quick search: show the task"),
                Shortcut(keys: "⌘↩", action: "In quick search: open the task's link"),
                Shortcut(keys: "⌘F", action: "Filter the tasks on screen"),
            ]
        ),
        (
            "View",
            [
                Shortcut(keys: "⌘1", action: "Show as grid"),
                Shortcut(keys: "⌘2", action: "Show as list"),
                Shortcut(keys: "⌘+", action: "Bigger text"),
                Shortcut(keys: "⌘-", action: "Smaller text"),
                Shortcut(keys: "⌘0", action: "Default text size"),
            ]
        ),
        (
            "Task editor",
            [
                Shortcut(keys: "⌘↩", action: "Save"),
                Shortcut(keys: "esc", action: "Cancel"),
            ]
        ),
        (
            "App",
            [
                Shortcut(keys: "⌘,", action: "Settings: theme, Google Drive, export and import"),
                Shortcut(keys: "⌘/", action: "This list"),
            ]
        ),
    ]

    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Keyboard shortcuts")
                .appFont(17, weight: .semibold)
            ForEach(Self.groups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title)
                        .appFont(11, weight: .semibold)
                        .foregroundStyle(Palette.mutedInk)
                    ForEach(group.shortcuts, id: \.self) { shortcut in
                        HStack(spacing: 12) {
                            KeyCap(shortcut.keys)
                                .frame(width: 96, alignment: .leading)
                            Text(shortcut.action)
                                .appFont(13)
                                .foregroundStyle(Palette.ink)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

/// Bottom of the sidebar: the two shortcuts worth knowing first, and the way to all of them.
struct ShortcutHint: View {
    let onShowAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                KeyCap("⌘K")
                Text("Find any task")
            }
            HStack(spacing: 6) {
                KeyCap("⌘N")
                Text("New task")
            }
            Button("All shortcuts (⌘/)", action: onShowAll)
                .buttonStyle(.link)
        }
        .appFont(11)
        .foregroundStyle(Palette.secondaryInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
