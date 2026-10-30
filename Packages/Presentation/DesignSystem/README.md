# DesignSystem

Layer: presentation. SPM target: `DesignSystem`.

## Scope

Shared look: color tokens, card chrome, buttons, badges, chips, metric tiles, toast.

## Owns

- `Palette`, `Metrics`, `.cardSurface()`, `.fieldChrome()`
- `PrimaryButtonStyle`, `SecondaryButtonStyle`, `ErrorLine`, `LabeledField`, `KeyCap`
- `Tint`, `Badge`, `FilterChip`, `MetricTile`, `Toast`

## Must not

- Import Domain, a Data module, or a feature

## Depends on

Nothing.

## Tests

None: views only.
