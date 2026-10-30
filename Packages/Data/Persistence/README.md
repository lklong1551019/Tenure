# Persistence

Layer: data. SPM target: `Persistence`.

## Scope

The data file on this Mac.

## Owns

- `LedgerFileCodec` (`LedgerCodecPort`): `tenure.json`, pretty-printed with sorted keys,
  `format`/`version` envelope; refuses newer versions, foreign files, and duplicate ids. The
  same bytes go to the local file and to Drive.
- `FileLedgerRepository` (`LedgerRepository`): atomic write (temp file, fsync, rename) to
  Application Support, 0600/0700
- `UserDefaultsSyncState` (`SyncStatePort`): last synced revision, fingerprint, pin day

## Must not

- Talk to the network
- Merge or interpret entries beyond decoding them

## Depends on

Domain

## Tests

`PersistenceTests` (8 tests): codec round trip and readable layout, newer, foreign, broken,
and duplicate files refused; repository load, save, permissions, no leftover temp files; sync
record round trip and clear. All files live in a temp directory.
