# BoardFeature

Layer: presentation. SPM target: `BoardFeature`.

## Scope

The main window: board sidebar, tasks as a grid or a table beside the selected task's story
(40/60, draggable, double-click the divider to reset), the board sheet, and Markdown export.
Sorted by date, the grid and the table group tasks under month headings (`EntryGroup`, pinned
in the grid); a card then shows its date without the year. A card's last line holds the link
as a ticket key in the accent color (`LinkLabel`: "PLA-6165", else "host · last part"), the
tags, and "No story" for a task without one, which also gets a dashed border. Board names show
only on All tasks with more than one board. The table's column widths, order, and hidden
columns are kept in UserDefaults (`tableColumns`); Name is the widest column by default and
cannot be hidden.

## Owns

- `BoardViewModel`, `BoardActions`, `BoardSelection`, `BoardLayout`, `BoardDraft`. Boards,
  live tasks, visible tasks, kinds, years, per-board counts, and board names are derived once
  per snapshot or filter change, not on each read: views read them many times per redraw.
  Changes made together (clearing filters, revealing a task, a new snapshot) refresh once.
- `BoardView`, `EntryCard`, `EntryDetailView`, `BoardEditorView`, `MonthPicker`
- Year filter: `YearCount`, `YearFilterChip` (a popover of the board's years with task
  counts); a card dated before the chosen year shows "Started in <year>"
- `StoryText` (inline Markdown, with `<b>`, `<i>`, `<code>`, `<br>` read as Markdown; links
  other than http and https stay plain text, and clicks go through `BoardActions.openLink`) and
  `StorySection` (each story part's symbol and tint)
- `ShortcutsView` (Help > Keyboard Shortcuts, Cmd-/) and the sidebar `ShortcutHint`
- Export: `YearExportDraft`, `ExportFile`, `YearExportView`, `MarkdownDocument` (save panel)
- Import: `ImportDraft`, `ImportTasksView` (paste or open a CSV/TSV, pick board and kind,
  preview every row, import the ready ones in one write; File > Import Tasks, Shift-Cmd-I)

## Must not

- Import a Data module or another feature; changes go through `BoardActions`

## Depends on

Domain, DesignSystem

## Tests

`BoardFeatureTests` (16 tests): board order and filtering, reveal across boards and filters,
selection fallback, board draft validation and save, failed save, new task target, board and
year export, copying a task, the summary line, HTML tags read as Markdown, the year filter (per-board counts, summary, reset), story links limited to http and
https, importing ready rows onto the chosen board, month groups, when board names show, and
link labels.
