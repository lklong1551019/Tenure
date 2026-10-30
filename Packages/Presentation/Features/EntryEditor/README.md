# EntryEditorFeature

Layer: presentation. SPM target: `EntryEditorFeature`.

## Scope

The task sheet: basics, the five-part story, and metrics.

## Owns

- `EntryEditorViewModel`, `EntryEditorActions`, `MetricDraft`
- `EntryEditorView`

## Must not

- Import a Data module or another feature; saving goes through `EntryEditorActions`

## Depends on

Domain, DesignSystem

## Tests

`EntryEditorFeatureTests` (4 tests): name required, trimming, tag parsing, blank metrics
dropped, incomplete metric blocks save, editing keeps id, creation stamp, and unknown kinds.
