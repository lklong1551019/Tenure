# Architecture

How a task gets from the editor into `tenure.json` on this Mac and in Google Drive, and back.

```
  SwiftUI features (Board, EntryEditor, Search, Settings)
      |  *Actions protocols
      v
  App (AppModel, AppDependencies: the composition root)
      |
      v
  Domain: LedgerStore --- MergePolicy --- SyncLedger <- SyncScheduler
      |  LedgerRepository / LedgerCodecPort        |  RemoteStorePort / DriveAccountPort
      v                                            v
  Data/Persistence                             Data/DriveSync
  Application Support/Tenure/tenure.json       My Drive / Tenure / tenure.json   (same bytes)
```

- **The local file is the source of truth.** Drive is a mirror and a backup. The app works
  offline; sync reconciles later.
- **Plain JSON, no encryption.** `tenure.json` is pretty-printed with sorted keys, so it reads
  well, diffs cleanly, and survives a hand edit.

The web app in `web/` works on the same file in Drive with ports of the same rules (codec,
merge, sync), tested against fixtures the Swift code writes; see [WEB.md](WEB.md).

## Modules

| Module | Role |
|---|---|
| `Domain` | Entities, `LedgerStore`, `EntryQuery`, `EntrySearch`, `MergePolicy`, sync, ports |
| `Data/Persistence` | `LedgerFileCodec`, atomic file store, sync bookkeeping in UserDefaults |
| `Data/DriveSync` | Google OAuth (PKCE), Drive REST v3 client |
| `Presentation/DesignSystem` | Palette, card chrome, buttons, badges, chips, metric tiles |
| `Presentation/Features/*` | Board, EntryEditor, Search, Settings |
| `App` | Composition root, `AppModel`, scenes, menu commands, menu bar menu, `GitHubReleaseFeed` |

Dependencies point inward: `Domain` imports Foundation only; Data and Presentation modules
depend on `Domain` and never on each other. `scripts/check-deps.sh` enforces it.

## Data model

- `Board`: a stretch of a career, `start` and optional `end` as `YearMonth` ("2017-07").
- `Entry`: one task on a board. Name, optional link, `EntryType` (an open string: product,
  dev, bugFix, findings, or anything a newer build writes), `DayDate` and optional end date,
  tags, five Markdown sections (problem, why, solution, impact, difficulties), and `Metric`s
  (label, before, after, unit, note; values are text).
- Every item carries `createdAt`, `updatedAt`, and `deletedAt`. A delete keeps the item as a
  tombstone so it reaches other Macs; deleting a board tombstones its entries.

Decoding is tolerant inside items: a missing or malformed field falls back to a default. Only
a missing `id`, `boardId`, or `updatedAt` makes a file unreadable, and an unreadable file is
never overwritten.

## Changes

`LedgerStore` is an actor. Each change is stamped (`updatedAt` = now, but always after the
item's previous stamp), written to disk atomically, and only then applied in memory and
published to observers. A failed write changes nothing.

## Merge

Per item, last writer wins on `updatedAt`. On a tie a delete beats an edit, then the larger
canonical JSON encoding wins, so every Mac picks the same winner in any order. Tombstones
older than 90 days are purged.

## Sync

```
  SyncScheduler: on launch (signed in), after sign-in, every 15 min,
                 5 s after the last edit, "Sync now"; one round at a time
      |
      v
  SyncLedger round
      head revision == last synced revision?
      +-- yes: local fingerprint changed? -- no --> up to date
      |                                    -- yes -> upload
      +-- no:  download -> checks -> LedgerStore.merge (saves) -> upload unless remote has it
      after upload: revisions since the base? another Mac's upload landed in between:
                    merge it and upload again (up to 3 attempts)
```

- The first upload of each UTC day is pinned (`keepForever`) as a backup revision.
- A remote copy from a newer format version, one that does not decode, or one with stamps more
  than a day in the future is refused; nothing local changes.
- `SnapshotFingerprint` (FNV-1a over item ids, stamps, and delete flags) tells whether local
  state differs from the last synced revision without downloading it.

## Drive layout

One folder and one file, each found by an `appProperties` marker (`tnRole`: `folder`,
`ledger`), never by name. Debug builds use the `dev` namespace: folder "Tenure (dev)", markers
`folder-dev` and `ledger-dev`. See `docs/GOOGLE-SETUP.md` for the Cloud project.

## Update checks

Tenure is built and installed on each Mac (`scripts/install-app.sh`), so there is no download
to fetch: the app only tells you a newer version exists and what changed. `GitHubReleaseFeed`
(App) reads `App/Sources/Changelog.json` from `main` on GitHub; that file changes only in
release commits, so it lists exactly the released versions. `UpdateCheck` (Domain) decodes it
and keeps the releases whose build code (YYMMNNBB) is higher than this build's, so a later
build of the same version (26.11.01 - 26110103) counts as an update. `UpdateViewModel`
(Settings) runs the check from Tenure > Check for Updates, Settings > About, and every 12
hours in the background (an hour after a failure), asking for the Software Update window
until it has shown a new build. The
feed runs off the main actor with no cookies or disk cache and reads at most 256 KB. It is a
port implemented in App rather than a Data module: one HTTPS GET with no credentials did not
justify a module of its own.

## Links

A task's link and links inside its story open only when they are http or https, with a host
and no user name in the address (`AppModel.openLink`). Story Markdown drops any other link, so
an imported or synced file cannot make a click open another app's URL scheme or a file.
