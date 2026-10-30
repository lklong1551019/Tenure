# BoardFeature

Layer: presentation. SPM target: `BoardFeature`.

## Scope

The main window: board sidebar, tasks as a grid or a table, the task inspector, and the board
sheet.

## Owns

- `BoardViewModel`, `BoardActions`, `BoardSelection`, `BoardLayout`, `BoardDraft`
- `BoardView`, `EntryCard`, `EntryDetailView`, `BoardEditorView`, `MonthPicker`
- `ShortcutsView` (Help > Keyboard Shortcuts, Cmd-/) and the sidebar `ShortcutHint`

## Must not

- Import a Data module or another feature; changes go through `BoardActions`

## Depends on

Domain, DesignSystem

## Tests

`BoardFeatureTests` (6 tests): board order and filtering, reveal across boards and filters,
selection fallback, board draft validation and save, failed save, new task target.
