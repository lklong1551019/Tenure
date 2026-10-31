# Releasing Tenure

A release is a version number, release notes, a tag, and an updated release history page at
https://lklong1551019.github.io/Tenure/releases.html. Two scripts do the work:

| Script | What it does |
|---|---|
| `scripts/release.sh` | Picks the version, writes the notes, renders the page, commits, tags, and offers to push |
| `scripts/install-app.sh` | Builds the Release app from the current commit and installs it in `/Applications` |

Nothing is uploaded to an App Store and nothing is notarized: you build and install on each
Mac you use.

## Before you start

- Every change you want in the release is committed on `main`, and `git status` is clean.
- `Config/Local.xcconfig` exists with your `DEVELOPMENT_TEAM`, and `Config/Secrets.xcconfig`
  holds the Google client (without it the app installs with sync off). See
  [GOOGLE-SETUP.md](GOOGLE-SETUP.md).
- You are online if you want to push at the end.

## Write commit subjects that become notes

The notes come from the commit subjects since the last release tag. Only four types make it
in; everything else is left out.

| Subject | Section in the notes |
|---|---|
| `feat: export a year to Markdown` | New |
| `fix: keep the detail pane full width` | Fixed |
| `ui: clearer filter chips` | Improved |
| `perf: faster grid with many tasks` | Improved |
| `chore:`, `docs:`, `test:`, `build:`, `ci:`, `refactor:`, `revert:` | left out |

A scope is fine (`feat(export): ...`). Write the subject the way a user should read it: the
script capitalises the first letter and otherwise keeps your words. You can still reword the
notes during the release.

## 1. Preview

```bash
scripts/release.sh --dry-run
```

Prints the next version, the notes, and what it would commit, tag, and push. Changes nothing.
If a line is missing, check that its commit subject starts with one of the four types above.

## 2. Release

```bash
scripts/release.sh
```

What happens, in order:

1. **Version.** The next `YY.MM.NN` for this month: the first release in November 2026 is
   `26.11.01`, the second `26.11.02`. The build code is `YYMMNN01` (`26110101`), and Debug
   builds from Xcode get `YYMMNN02` (`26110102`).
2. **Notes.** A new entry for this version goes into `App/Sources/Changelog.json`, and the
   notes are printed.
3. **Pause to reword.** The script waits. Open `App/Sources/Changelog.json`, edit the
   `new`, `fixed`, and `improved` lines of the new entry if you want them clearer, save, and
   press Return. To keep them as they are, just press Return.
4. **Page.** `site/releases.html` is rendered from the changelog.
5. **Checks.** `scripts/verify.sh` runs: build, tests, dependency rule, format, app build,
   and a secret scan. If any fail, the script puts every file back and stops.
6. **Commit and tag.** It asks `Commit and tag 26120101? [y/N]`. Answer `y` to commit
   `chore: release 26.12.01 - 26120101` (changelog, version numbers in `Config/Base.xcconfig`,
   and the page) and create the annotated tag `26120101`, the build code. Any other answer
   puts everything back.
7. **Push.** It asks `Push main and 26120101 to origin? This deploys the release page. [y/N]`.
   - `y` pushes `main` and the tag. The Pages workflow publishes the new release page about a
     minute later (watch it under the repository's Actions tab).
   - Anything else keeps the release local. Push later with
     `git push --follow-tags origin main`.

### Choosing the version yourself

By default the version follows the calendar month. To release a specific version instead,
for example to start November's numbering early:

```bash
scripts/release.sh --dry-run --version 26.11.01
scripts/release.sh --version 26.11.01
```

The build code follows from it (`26110101`). The script refuses a version that is not
`YY.MM.NN`, already has a tag, or is not newer than the last release, so update checks keep
working: an installed app only offers builds newer than its own.

### Shipping a new build of the same version

To ship more changes without a new version number, release a later build of the last
version:

```bash
scripts/release.sh --dry-run --build 03
scripts/release.sh --build 03
```

This releases code `26110103` of version 26.11.01: tag `26110103`, its own entry in the
changelog and on the release page ("26.11.01 - 26110103"), with the notes since the previous
release. Builds are odd, 03 to 99, and must be higher than the last release's code. Software
Update compares codes, so an installed 26.11.01 - 26110101 is offered 26110103.

## 3. Install

```bash
scripts/install-app.sh
```

Builds Release from the current commit, checks the bundle id, signature, and sandbox, quits
any running Tenure, installs to `/Applications`, and opens it. Your data is not touched: it
lives in the app's container, not inside the app.

### Build codes

The version (Settings > About) and build come from the newest release tag. Release tags are
build codes (`26110103`; the first release was tagged `v26.11.01`). The build code tells
builds apart:

| Build | Code | Example |
|---|---|---|
| Release, the tagged commit | the tag | `26110103` (and `v26.11.01` → `26110101`) |
| Release, later commits | odd: the tag's build + 2 per commit after it | 2 commits after `26110103` → `26110107` |
| Release, chosen by hand | `--build 07` (odd, 01-99) | `26110107` |
| Debug, run from Xcode | even: the last release's code + 1 | `26110102` |

Odd is what you install and use ("prod"), even is a development build: the code alone says
which. Software Update and the release page go by released codes: to have other Macs offered
your changes, release them (`scripts/release.sh --build 03`, or a new version); a build you
only install locally is not announced.

Useful options: `--build-only` to build and check without installing, `--skip-verify` to skip
the checks when you just ran them, `--dest DIR` to install somewhere else, `--build 03` to
choose the build number.

## Checking the result

- https://lklong1551019.github.io/Tenure/releases.html lists the new version at the top with
  a "Latest" pill.
- `git tag` shows the build code, such as `26110103`; `git show 26110103` prints the notes.
- Settings > About in the installed app shows the version and build.

## When something goes wrong

| Message | What to do |
|---|---|
| `uncommitted changes; commit or stash them first` | Commit or stash, then run again |
| `on <branch>; releases come from main` | Merge to `main`, or pass `--allow-branch` on purpose |
| `scripts/verify.sh` failed | Fix what it names; the script already put every file back |
| `push failed; v... is committed and tagged locally` | Fix the network or credentials, then `git push --follow-tags origin main` |
| Release page did not change | Check the Pages run in the Actions tab; rerun it with Run workflow |
| `N commits since v...; cut a release` (install) | More than 49 commits after the last tag: release first, or pass `--build` |
| `--build 04: Release builds are odd` (install) | Pick an odd build number; even codes are Debug builds |

To undo a release that was tagged but not pushed:

```bash
git tag -d 26110103
git reset --hard HEAD~1
```

`git reset --hard` drops the release commit and any uncommitted changes, so run it only right
after the release. Once a release is pushed, do not rewrite it: cut the next one instead.
