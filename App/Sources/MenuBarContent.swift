import AppKit
import BoardFeature
import Domain
import SwiftUI

/// The menu bar icon's menu: add a task or find one without hunting for the window, and jump
/// back to what you touched last. Every item brings the main window forward first.
struct MenuBarContent: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    static let recentCount = 5

    var body: some View {
        Button("New Task...") {
            showMainWindow()
            model.newEntry()
        }
        .disabled(model.board?.boards.isEmpty ?? true)
        Button("Quick Search...") {
            showMainWindow()
            if model.quickSearch == nil { model.toggleQuickSearch() }
        }
        .disabled(!model.isReady)
        let recent = recentEntries
        if !recent.isEmpty {
            Divider()
            Section("Recently changed") {
                ForEach(recent) { entry in
                    Button(title(of: entry)) {
                        showMainWindow()
                        model.board?.reveal(entry.id)
                    }
                }
            }
        }
        Divider()
        Button("Open Tenure") { showMainWindow() }
        SettingsLink { Text("Settings...") }
        Divider()
        Button("Quit Tenure") { NSApp.terminate(nil) }
    }

    private var recentEntries: [Entry] {
        guard let board = model.board else { return [] }
        return Array(board.liveEntries.sorted { $0.updatedAt > $1.updatedAt }.prefix(Self.recentCount))
    }

    private func title(of entry: Entry) -> String {
        let board = model.board?.boardName(of: entry) ?? ""
        return board.isEmpty ? entry.displayName : "\(entry.displayName) · \(board)"
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApp.activate()
    }
}
