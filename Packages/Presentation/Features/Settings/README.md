# SettingsFeature

Layer: presentation. SPM target: `SettingsFeature`.

## Scope

The Settings window: Google Drive sign-in and sync status, and the data file (show in
Finder, export, import).

## Owns

- `SettingsViewModel`, `SettingsActions`, `SettingsView`, `JSONFile`
- Preferences: `AppTheme`, `TextSize` (stored by the app), `AboutInfo`, `AboutView`

## Must not

- Import a Data module or another feature

## Depends on

Domain, DesignSystem

## Tests

None yet.
