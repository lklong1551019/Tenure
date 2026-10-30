# DesignSystem

Layer: presentation. SPM target: `DesignSystem`.

## Scope

Shared look: color tokens, card chrome, buttons, badges, chips, metric tiles, toast.

## Owns

- `Palette`, `Metrics`, `.cardSurface()`, `.cardShadow()`, `.fieldChrome()`
- `.appFont(_:weight:design:)` and the `textScale` environment value (the text size setting)
- `PrimaryButtonStyle`, `SecondaryButtonStyle`, `ErrorLine`, `LabeledField`, `KeyCap`
- `Tint`, `Badge`, `FilterChip`, `MetricTile`, `ChangePill`, `Toast`, `FlowRow`

## Must not

- Import Domain, a Data module, or a feature

## Depends on

Nothing.

## Tests

None: views only.
