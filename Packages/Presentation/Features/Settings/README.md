# SettingsFeature

Layer: presentation. SPM target: `SettingsFeature`.

## Scope

The Settings window (appearance: theme, text size, menu bar icon; Google Drive sign-in and sync
status; the data file: show in Finder, export, import; About) and the Software Update window
(newer versions and their notes, checked on request and every 12 hours).

## Owns

- `SettingsViewModel`, `SettingsActions`, `SettingsView`, `JSONFile`
- Preferences: `AppTheme`, `TextSize`, `MenuBarIcon` (stored by the app), `AboutInfo`, `AboutView`
- Updates: `UpdateViewModel`, `UpdateActions`, `UpdateState`, `UpdateView` (window id `updates`).
  The view model keeps its own UserDefaults keys: the 12-hour switch, the last check, and the
  last version announced, so a background check opens the window once per version.

## Must not

- Import a Data module or another feature

## Depends on

Domain, DesignSystem

## Tests

`SettingsFeatureTests` (5 tests): manual check outcomes (newer, up to date, offline), one
announcement per version, the automatic switch, the 12-hour schedule, copying the install
command.
