# Tenure on the web

The web app at https://lklong1551019.github.io/Tenure/app/ reads and edits the same
`tenure.json` in Google Drive as the Mac app. It is static files on GitHub Pages: no server, no
analytics, nothing stored in the browser but two display settings. Source in `web/`.

```
  React screens (web/src/app, web/src/ui)
      |
      v
  AppModel: sign-in, sync schedule, "can edit"
      |
      v
  domain: LedgerStore --- merge --- SyncLedger          (ports of Packages/Domain)
      |  LedgerCodecPort                 |  RemoteStorePort
      v                                  v
  data: ledgerFileCodec              data: DriveClient + GoogleAuth   (ports of Packages/Data)
                                         My Drive / Tenure / tenure.json   (same file, same bytes)
```

## The same data as the Mac

The rules that touch the file are ports of the Swift code, kept line for line where possible:

| `web/src/...` | Swift |
|---|---|
| `domain/model.ts`, `calendar.ts`, `timestamp.ts`, `story.ts` | `Domain/Sources/Model` |
| `domain/coding.ts` (tolerant decoding), `domain/jsonText.ts` (JSONEncoder layouts) | Codable conformances |
| `data/ledgerFileCodec.ts` | `Data/Persistence/Sources/LedgerFileCodec.swift` |
| `domain/merge.ts` | `Domain/Sources/Merge/MergePolicy.swift` |
| `domain/fingerprint.ts` | `SnapshotFingerprint` in `Domain/Sources/Sync/SyncTypes.swift` |
| `domain/ledgerStore.ts` | `Domain/Sources/Store/LedgerStore.swift` |
| `domain/sync/syncLedger.ts`, `remoteCheck.ts` | `Domain/Sources/Sync/SyncLedger.swift`, `RemoteLedgerCheck.swift` |
| `domain/query.ts`, `search.ts`, `markdownExport.ts` | `EntryQuery`, `EntrySearch`, `MarkdownExport` |
| `data/driveClient.ts`, `httpTransport.ts` | `Data/DriveSync/Sources/DriveClient.swift`, `HTTPTransport.swift` |
| `ui/editor/drafts.ts` | `BoardDraft`, `EntryEditorViewModel` |
| `ui/components/inlineMarkdown.ts` | `StoryText` in `Board/Sources/Display.swift` |

So a file the web writes is byte for byte what the Mac would write for the same data
(pretty-printed, sorted keys, `"key" : value`), a newer format version is refused, decoding
stays tolerant inside items, and both merge per item, last writer wins on `updatedAt`, with
the same tie rules (a delete wins, then the larger canonical encoding compared as UTF-8 bytes,
with `/` escaped as Swift's `JSONEncoder` does). The Mac and the web converge whichever syncs
first, and neither loses the other's edits.

### Fixtures from the Swift code

`Packages/IntegrationTests/WebFixtureTests.swift` runs the Swift codec, merge, fingerprint,
query, search, and export on fixed inputs and compares the results with
`web/test/fixtures/*.json`. The web tests read the same files and must reproduce them exactly.
A rule changed on one side only fails a test on that side. After a deliberate change:

```bash
TENURE_WRITE_FIXTURES=1 swift test --package-path Packages --filter WebFixture
npm --prefix web test
```

Nothing that depends on the time zone is in the fixtures; the fallback date for a malformed
one (the local day of `updatedAt`) is tested on each side.

## Where the web differs from the Mac, on purpose

- **It never creates the file.** No `tenure.json` found by its marker means "turn on sync in the
  Mac app first". A second file would split the data.
- **It never pins a revision.** The Mac keeps the first upload of each day forever; Drive allows
  200 such revisions per file, and one device doing it is enough.
- **No local copy.** The ledger lives in memory while the page is open. Edits are uploaded 2 s
  after the last one, when the tab is hidden, and on "Sync now"; closing the tab with edits not
  yet in Drive asks first. Remote changes come in on sign-in and every 5 minutes.
- **Edits wait for the file.** Nothing can be changed until the first sync has read the file,
  and editing stops while the file is refused (newer version, unreadable, missing).
- Names sort with `Intl.Collator` where the Mac uses `localizedStandardCompare`; this only
  orders a list, never decides data.

## Sign-in

Google Identity Services, token model, scope `drive.file` only. The access token lasts about an
hour and is kept in memory; there is no refresh token in the browser. Each visit starts with
"Sign in with Google", and when the hour runs out a banner asks for one click; Google
remembers the consent, so the popup closes by itself and edits on the page are kept. A longer
session would need a server holding a client secret, which this app does not have.

`drive.file` lets an app open the files it created. The web uses a second OAuth client in the
same Google Cloud project as the Mac app's. Google's documentation does not state in so many
words that this access is per project rather than per client (the Picker's `setAppId`, which
takes the project number, suggests it is); it was confirmed on 31 October 2026, when the web
client read and wrote the file the Mac's iOS-type client created. If the file is ever not
visible, the web shows "No Tenure file in this Drive yet" and changes nothing; the fallback
would be the Google Picker.

Sign out revokes the web client's grant; the Mac's grant is separate and stays.

`?ns=dev` reads and writes the file of the Mac app's Debug builds (marker `ledger-dev`), to try
the web on test data.

## Running it

```bash
cd web
npm ci
npm run dev        # http://localhost:5173/Tenure/app/  (?demo: sample data, no Google)
npm run check      # typecheck, lint, format, tests
npm run build      # into web/dist
```

`web/.env.local` (ignored) holds `VITE_GOOGLE_CLIENT_ID=<web client id>` for local sign-in; the
client must list `http://localhost:5173` as an authorized JavaScript origin. Without it the
page says sync isn't set up; `?demo` works anyway.

## Deploying

`.github/workflows/pages.yml` runs `npm ci`, `npm run check`, and `npm run build` with
`VITE_GOOGLE_CLIENT_ID` from the repository variable `GOOGLE_WEB_CLIENT_ID`, copies `web/dist`
into `site/app`, and publishes `site/`. Pull requests run the same build without deploying.

## Google setup

See [GOOGLE-SETUP.md](GOOGLE-SETUP.md#6-web-client).

## Layers

`web/src` keeps the Swift package's dependency rule, enforced by ESLint
(`no-restricted-imports` in `web/eslint.config.js`):

| Folder | May import |
|---|---|
| `domain` | nothing but `domain` |
| `data` | `domain` |
| `ui` | `domain` (and React) |
| `app` | everything: the composition root |
