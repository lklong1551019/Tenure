import AppKit
import BoardFeature
import DesignSystem
import EntryEditorFeature
import SearchFeature
import SettingsFeature
import SwiftUI

@main
struct TenureApp: App {
    @State private var model = AppModel()
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system
    @AppStorage(TextSize.storageKey) private var textSize: TextSize = .standard
    @AppStorage(MenuBarIcon.storageKey) private var showsMenuBarIcon = true
    /// Read once: the bundle's version does not change while running.
    private let about = AboutInfo.load()

    var body: some Scene {
        Window("Tenure", id: "main") {
            RootView(model: model)
                .frame(minWidth: 1000, minHeight: 640)
                .textSize(textSize)
                .preferredColorScheme(theme.colorScheme)
                .task { await model.start() }
                .onAppear { apply(theme) }
                .onChange(of: theme) { _, newTheme in apply(newTheme) }
        }
        .defaultSize(width: 1320, height: 820)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesButton(updates: model.updates)
            }
            CommandGroup(replacing: .newItem) {
                Button("New Task") { model.newEntry() }
                    .keyboardShortcut("n", modifiers: [.command])
                    .disabled(model.board?.boards.isEmpty ?? true)
                Button("New Board") { model.newBoard() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .disabled(!model.isReady)
            }
            CommandGroup(replacing: .importExport) {
                Button("Export Board as Markdown...") { model.board?.exportCurrent() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(!(model.board?.canExport ?? false))
                Button("Export a Year as Markdown...") { model.board?.beginYearExport() }
                    .disabled(!(model.board?.canExport ?? false))
                Button("Copy Task as Markdown") { model.board?.copySelectedEntry() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(model.board?.selectedEntry == nil)
            }
            // Replaces the standard Find items: Cmd+F filters the board, Cmd+K opens quick search.
            CommandGroup(replacing: .textEditing) {
                Button("Filter Tasks") { model.board?.focusSearch() }
                    .keyboardShortcut("f", modifiers: [.command])
                    .disabled(!model.isReady)
                Button("Quick Search") { model.toggleQuickSearch() }
                    .keyboardShortcut("k", modifiers: [.command])
                    .disabled(!model.isReady)
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") { model.board?.showsShortcuts = true }
                    .keyboardShortcut("/", modifiers: [.command])
                    .disabled(!model.isReady)
            }
            CommandGroup(before: .toolbar) {
                Button("As Grid") { model.board?.layout = .grid }
                    .keyboardShortcut("1", modifiers: [.command])
                    .disabled(!model.isReady)
                Button("As List") { model.board?.layout = .list }
                    .keyboardShortcut("2", modifiers: [.command])
                    .disabled(!model.isReady)
                Divider()
                Button("Bigger Text") { textSize = textSize.larger ?? textSize }
                    .keyboardShortcut("+", modifiers: [.command])
                    .disabled(textSize.larger == nil)
                Button("Smaller Text") { textSize = textSize.smaller ?? textSize }
                    .keyboardShortcut("-", modifiers: [.command])
                    .disabled(textSize.smaller == nil)
                Button("Default Text Size") { textSize = .standard }
                    .keyboardShortcut("0", modifiers: [.command])
                    .disabled(textSize == .standard)
                Divider()
            }
        }

        Window("Software Update", id: UpdateView.windowID) {
            UpdateView(model: model.updates)
                .textSize(textSize)
                .preferredColorScheme(theme.colorScheme)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra("Tenure", systemImage: "rectangle.stack", isInserted: $showsMenuBarIcon) {
            MenuBarContent(model: model)
        }

        Settings {
            Group {
                if let settings = model.settings {
                    SettingsView(
                        model: settings,
                        theme: $theme,
                        textSize: $textSize,
                        showsMenuBarIcon: $showsMenuBarIcon,
                        about: about
                    )
                } else {
                    Text("Open the main window first.")
                        .padding(40)
                }
            }
            .textSize(textSize)
            .preferredColorScheme(theme.colorScheme)
        }
    }

    /// The app-wide appearance also covers sheets, menus, and AppKit-drawn controls, which
    /// `preferredColorScheme` alone does not reach.
    private func apply(_ theme: AppTheme) {
        NSApp.appearance =
            switch theme {
            case .system: nil
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
    }
}

extension View {
    /// Scales every `appFont`, and the default font of text that sets none (lists, tables,
    /// form labels), by the text size setting.
    fileprivate func textSize(_ size: TextSize) -> some View {
        environment(\.textScale, size.scale)
            .font(.system(size: (13 * size.scale).rounded()))
    }
}

/// Tenure > Check for Updates...: opens the window and checks again.
private struct CheckForUpdatesButton: View {
    let updates: UpdateViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Check for Updates...") {
            openWindow(id: UpdateView.windowID)
            Task { await updates.check() }
        }
    }
}

struct RootView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        content
            .sheet(item: $model.editor) { editor in
                EntryEditorView(model: editor)
            }
            .overlay {
                if let quickSearch = model.quickSearch {
                    QuickSearchView(model: quickSearch)
                }
            }
            // A background check found a version not announced before.
            .onChange(of: model.updates.windowRequests) { openWindow(id: UpdateView.windowID) }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .launching:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.ground)
        case .failed(let message):
            Text(message)
                .foregroundStyle(Palette.danger)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.ground)
        case .ready(let board):
            BoardView(model: board)
        }
    }
}
