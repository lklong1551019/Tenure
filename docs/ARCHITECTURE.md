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

## Modules

| Module | Role |
|---|---|
| `Domain` | Entities, `LedgerStore`, `EntryQuery`, `EntrySearch`, `MergePolicy`, sync, ports |
| `Data/Persistence` | `LedgerFileCodec`, atomic file store, sync bookkeeping in UserDefaults |
| `Data/DriveSync` | Google OAuth (PKCE), Drive REST v3 client |
| `Presentation/DesignSystem` | Palette, card chrome, buttons, badges, chips, metric tiles |
| `Presentation/Features/*` | Board, EntryEditor, Search, Settings |
| `App` | Composition root, `AppModel`, scenes and menu commands |

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
