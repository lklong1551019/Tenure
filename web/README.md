# web

Tenure in the browser: React, TypeScript, Vite. Reads and edits the Mac app's `tenure.json`
in Google Drive. Built into `site/app/` by `.github/workflows/pages.yml`.

## Scope

The web app: sign-in, sync, boards and tasks, editing, Markdown export.

## Owns

`src/domain` (ports of `Packages/Domain`), `src/data` (codec, Drive, Google sign-in),
`src/ui` (components), `src/app` (composition root and screens), `test/` (fixtures written by
the Swift code, fakes).

## Must not

Store tokens or ledger data in the browser; create the Drive file; change a rule in `domain`
or `data/ledgerFileCodec.ts` without the Swift side and the fixtures (see `docs/WEB.md`).

## Depends on

React, react-router-dom. Google Identity Services, loaded at run time from accounts.google.com.

## Tests

`npm run check`: Vitest against the Swift fixtures (codec, merge, fingerprint, query, search,
export), the store, sync with an in-memory Drive, the Drive client, editor drafts, and the
story Markdown parser.
