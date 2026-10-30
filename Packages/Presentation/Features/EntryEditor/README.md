# EntryEditorFeature

Layer: presentation. SPM target: `EntryEditorFeature`.

## Scope

The task sheet: basics, the five-part story with Markdown format buttons, and metrics.

## Owns

- `EntryEditorViewModel`, `EntryEditorActions`, `MetricDraft`
- `EntryEditorView` and its `StoryField` (a story part with B, I, code, and link buttons:
  Cmd-B, Cmd-I, Cmd-E, Cmd-L, active only while that field has focus)
- `MarkdownFormat`: wraps or unwraps the selection in Markdown markers

## Must not

- Import a Data module or another feature; saving goes through `EntryEditorActions`

## Depends on

Domain, DesignSystem

## Tests

`EntryEditorFeatureTests` (10 tests): name required, trimming, tag parsing, blank metrics
dropped, incomplete metric blocks save, editing keeps id, creation stamp, and unknown kinds;
Markdown formatting wraps, unwraps, keeps bold intact under italic, places the cursor in an
empty pair, selects a new link's address, and clamps out-of-range selections.
