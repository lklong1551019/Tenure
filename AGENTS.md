# AGENTS.md

Working notes for anyone, human or agent, changing this repository. Only what cannot be read
off the code. For how the pieces fit together, read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
`CLAUDE.md` is a symlink to this file; edit this file only.

## Read first

If `HANDOFF.md` exists at the repository root, read it before anything else. It carries
in-flight state from a previous session and is not tracked in git.

## What this is

A macOS app that records a career: boards per company and time span, tasks with a link, a
kind, a five-part story, and before/after metrics. Grid or list, sort and filter, Cmd+K. One
plain JSON file, synced to Google Drive. Swift 6, SwiftUI, macOS 26, no server. The
architecture follows Credentials Manager (`../Credentials Manager`), minus encryption, lock,
and onboarding.

## Invariants

**Never lose a user's data.** The store writes before it applies; a failed write changes
nothing. An unreadable or newer-version file is refused, never overwritten.

**Decoding stays tolerant inside items.** A value an older or newer build wrote (an unknown
`type`, a malformed date, an extra field) must map to something valid, never fail the item.
Only `id`, `boardId`, and `updatedAt` are required.

**The file format is versioned.** Any change to the layout of `tenure.json` that an older
build would misread bumps `LedgerFileCodec.currentVersion` and ships a migration with tests.
Adding an optional field does not need a bump.

**Every change moves `updatedAt`.** Sync and merge rely on it; go through `LedgerStore`,
never write the file another way.

**Dependencies point inward.** `Domain` imports Foundation only. `Presentation/*` and `Data/*`
depend on `Domain` and never on each other. `App` is the only module that sees all.
`scripts/check-deps.sh` enforces this.

**No realistic secret values in the repository.** Examples and placeholders use the literal
`temp`. `Config/Secrets.xcconfig` and `Config/Local.xcconfig` are ignored and blocked by the
pre-commit hook.

## Layout

| Path | Role |
|---|---|
| `Packages/Package.swift` | One SPM package (`TenureKit`), one target per module |
| `Packages/Domain` | Entities, store, query, search, merge, sync, ports |
| `Packages/Data/Persistence` | `tenure.json` codec, atomic file store, sync bookkeeping |
| `Packages/Data/DriveSync` | Google OAuth, Drive REST v3 client |
| `Packages/Presentation/DesignSystem` | Tokens and shared components |
| `Packages/Presentation/Features/*` | Board, EntryEditor, Search, Settings |
| `Packages/IntegrationTests` | Test-only: sync against real files |
| `Tenure.xcodeproj` | App target only; build settings live in `Config/Base.xcconfig` |
| `App/Sources` | Composition root (`AppDependencies`), `AppModel`, scenes |
| `Config/` | `Base.xcconfig` (tracked); `Local.xcconfig` and `Secrets.xcconfig` (ignored) |
| `site/` | Home page and privacy policy for the Google OAuth consent screen, release history (GitHub Pages) |
| `docs/` | Architecture, Google setup, releasing |
| `scripts/` | Dependency check, verify, git hooks, install, release, app icon renderer |

Every module directory carries a `README.md` (Scope, Owns, Must not, Depends on, Tests). The
pre-commit hook rejects a module without one.

## Build and test

```bash
swift build --package-path Packages
swift test --package-path Packages
scripts/check-deps.sh
xcrun swift-format lint --strict --recursive Packages App/Sources scripts
xcodebuild -project Tenure.xcodeproj -scheme Tenure \
  -derivedDataPath .build/xcode -allowProvisioningUpdates build
```

Once per clone:

```bash
scripts/git-hooks/install.sh
cp Config/Local.example.xcconfig Config/Local.xcconfig   # then set DEVELOPMENT_TEAM
```

`scripts/verify.sh` runs all of the above plus a secret-value scan of uncommitted changes.
Run it before every commit.

## Releasing

From a clean `main`: `scripts/release.sh`, then `scripts/install-app.sh`. The release script
picks the next `YY.MM.NN`, adds the `feat`/`fix`/`ui`/`perf` commit subjects since the last tag
to `App/Sources/Changelog.json` (reword them there when it pauses), renders
`site/releases.html`, runs `scripts/verify.sh`, then commits `chore: release <version>` and
tags `v<version>`. Answering y to its push question pushes `main` and the tag, which deploys
the release page at https://lklong1551019.github.io/Tenure/releases.html. `--dry-run` prints
the version and notes and changes nothing; `--version YY.MM.NN` picks the version instead of
the calendar. Commit subjects read `feat: add markdown export`
(optionally `feat(scope): ...`); other types stay out of the notes. Step by step, with what
to do when it fails: [docs/RELEASE.md](docs/RELEASE.md).

## Conventions

- Swift Testing (`@Suite`, `@Test`), no XCTest. Fakes live in each test target's `Fakes.swift`.
- Features talk to the app through a `*Actions` protocol and never see a port.
- UI copy is sentence case; plain ASCII hyphens, no em dashes.
