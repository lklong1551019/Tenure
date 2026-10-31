# Tenure

A macOS app for keeping a record of what you did in your career.

- **Boards** for each stretch of your career, such as Company A from July 2017 to August 2019.
- **Tasks** on each board, each with a name, an optional ticket link, a kind (product, dev, bug
  fix, findings), a date, and tags.
- **The story** of each task: the problem, why it mattered, the solution, the impact, the
  difficulties and how you solved them, and **metrics**, before and after, with how they were
  measured.
- **Grid or list**, sorted by date or name, filtered by board, kind, and text. Cmd+K finds any
  task.
- **Google Drive sync** of one plain JSON file. No encryption, no server.
- **On the web** at https://lklong1551019.github.io/Tenure/app/: the same file, read and
  edited in the browser, on any computer or phone.

Swift 6, SwiftUI, macOS 26. No third-party dependencies. The web app is React, TypeScript,
and Vite ([docs/WEB.md](docs/WEB.md)).

## Setup

```bash
scripts/git-hooks/install.sh
cp Config/Local.example.xcconfig Config/Local.xcconfig   # then set DEVELOPMENT_TEAM
```

For sync, follow [docs/GOOGLE-SETUP.md](docs/GOOGLE-SETUP.md) and fill in
`Config/Secrets.xcconfig`. Without it the app runs with sync off.

Open `Tenure.xcodeproj` and run the `Tenure` scheme, or install a Release build with
`scripts/install-app.sh`.

## Data

`~/Library/Containers/com.lklong1997.Tenure/Data/Library/Application Support/Tenure/tenure.json`
(Debug builds: `com.lklong1997.Tenure.dev`). Settings > Data shows it in Finder and exports
or imports a copy.

## Docs

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): modules, data model, merge, and sync
- [docs/GOOGLE-SETUP.md](docs/GOOGLE-SETUP.md): Google Cloud project and OAuth clients
- [docs/WEB.md](docs/WEB.md): the web app, and how it stays in step with the Mac
- [docs/RELEASE.md](docs/RELEASE.md): cutting a release, the release history page, and installing
- [AGENTS.md](AGENTS.md): working notes for changing this repository
