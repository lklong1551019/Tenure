# BoardFeature

Layer: presentation. SPM target: `BoardFeature`.

## Scope

The main window: board sidebar, tasks as a grid or a table beside the selected task's story
(40/60, draggable, double-click the divider to reset), the board sheet, and Markdown export.

## Owns

- `BoardViewModel`, `BoardActions`, `BoardSelection`, `BoardLayout`, `BoardDraft`. Boards,
  live tasks, visible tasks, kinds, per-board counts, and board names are derived once per
  snapshot or filter change, not on each read: views read them many times per redraw.
- `BoardView`, `EntryCard`, `EntryDetailView`, `BoardEditorView`, `MonthPicker`
- `StoryText` (inline Markdown, with `<b>`, `<i>`, `<code>`, `<br>` read as Markdown) and
  `StorySection` (each story part's symbol and tint)
- `ShortcutsView` (Help > Keyboard Shortcuts, Cmd-/) and the sidebar `ShortcutHint`
- Export: `YearExportDraft`, `ExportFile`, `YearExportView`, `MarkdownDocument` (save panel)

## Must not

- Import a Data module or another feature; changes go through `BoardActions`

## Depends on

Domain, DesignSystem

## Tests

`BoardFeatureTests` (10 tests): board order and filtering, reveal across boards and filters,
selection fallback, board draft validation and save, failed save, new task target, board and
year export, copying a task, the summary line, and HTML tags read as Markdown.
