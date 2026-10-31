# App

Layer: app. Xcode target `Tenure` (`Tenure.xcodeproj`); build settings in `Config/Base.xcconfig`.

## Scope

The composition root and the scenes: the only code that sees every module. It builds the port
implementations, owns the app state, and turns features' `*Actions` calls into store, sync,
and system calls.

## Owns

- `AppDependencies`: which implementation backs each port (`FileLedgerRepository`,
  `DriveClient`, `GoogleAuth`, `UserDefaultsSyncState`, `GitHubReleaseFeed`); reads the
  Google client and Drive namespace from `Info.plist`
- `AppModel`: launch, the feature view models, every `*Actions` protocol (imports land in one
  store write), link opening (http and https only, no user name in the address), the
  pasteboard, the 12-hour update timer
- `TenureApp`: the main window, Software Update window, menu bar menu, Settings scene, menu
  commands, theme and text size
- `MenuBarContent`: new task, quick search, recently changed tasks
- `GitHubReleaseFeed`: the published `Changelog.json` on `main`, off the main actor, 256 KB cap
- `Changelog.json`: release notes written by `scripts/release.sh`; `Assets.xcassets`: AppIcon
  and AppIconDev rendered by `scripts/render-app-icon.swift`
- `Info.plist`, `Tenure.entitlements` (sandbox, network client, user-selected files, Keychain)

## Must not

- Hold business rules: merge, query, export, and sync logic live in `Domain`
- Hand a port to a feature: features see only their `*Actions` protocol

## Depends on

Every module in `Packages/`.

## Tests

None in this target: its logic is thin glue, and the rules it calls are tested in their
modules. `scripts/verify.sh` builds it with `xcodebuild`.
