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
  The view model keeps its own UserDefaults keys: the 12-hour switch, the last attempt and
  whether it failed (retry in an hour), and the last version the window showed, so a
  background check asks for the window until it has shown a new version once.

## Must not

- Import a Data module or another feature

## Depends on

Domain, DesignSystem

## Tests

`SettingsFeatureTests` (6 tests): manual check outcomes (newer, up to date, offline), asking
for the window until it shows a version, a failed background check keeping the state and
retrying in an hour, the automatic switch, the 12-hour schedule, copying the install command.
