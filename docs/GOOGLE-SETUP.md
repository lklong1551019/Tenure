# Google setup

One-time setup of the Google Cloud project that lets Tenure sync `tenure.json` to Google
Drive. Only the OAuth client id and its redirect scheme reach the app; they go in the ignored
`Config/Secrets.xcconfig`. There is no client secret: the client is a public (iOS-type) client
and the sign-in uses PKCE.

## 1. Project and API

1. In the Google Cloud console, create a project, for example `tenure`.
2. Search for **Google Drive API** and click **Enable**.

## 2. Google Auth Platform

Console path: Google Auth Platform (the former "OAuth consent screen").

1. **Get started**: app name `Tenure`, a support email, audience **External** for a personal
   Google account, and a contact email.
2. **Data Access** -> Add or remove scopes: `.../auth/drive.file` only. It is non-sensitive and
   needs no Google verification. The app asks for no profile or email scope.
3. **Branding**: no logo (a logo requires verification). Publishing an External app needs a
   home page and a privacy policy on a domain listed under **Authorized domains**. This repo
   ships both in `site/`, deployed by `.github/workflows/pages.yml` to
   `https://<user>.github.io/<repo>/`; add `<user>.github.io` as the authorized domain, and
   `https://<user>.github.io/<repo>/` and `.../privacy.html` as the two links.
4. **Audience** -> **Publish app**, so the status reads **In production**. In "Testing", Google
   expires refresh tokens after 7 days and sync stops until the next sign-in. Until publishing
   works, add the signing-in account under **Test users**.

## 3. OAuth client

1. **Clients** -> Create client.
2. Application type: **iOS**. The app runs on macOS, but this type allows a redirect to the
   app's own URL scheme without a client secret.
3. Bundle ID: `APP_BUNDLE_ID` from `Config/Base.xcconfig` (`com.lklong1997.Tenure`), or its
   override in `Config/Local.xcconfig`. App Store ID, Team ID, App Check: empty.
4. From the created client, note the **Client ID** and the **iOS URL scheme** (the reversed
   client id, `com.googleusercontent.apps.<id>`). A new client can take from minutes to a few
   hours to start working.

## 4. Development client (optional)

Debug builds run as `APP_BUNDLE_ID.dev`, with their own data file and Drive folder
("Tenure (dev)"), so experiments never touch the real data. For sync in Debug, create a second
iOS client the same way with the `.dev` bundle id. Without it, Debug builds show "sync isn't
set up" and Release is unaffected.

## 5. Local configuration

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Set `GOOGLE_CLIENT_ID` to the Client ID and `GOOGLE_REVERSED_CLIENT_ID` to the iOS URL scheme,
without quotes; the `_DEV` pair takes the development client, or is removed. The file is
git-ignored and blocked by the pre-commit hook; examples anywhere else use `temp`. A build
without it has sync turned off.

## 6. Web client

The web app (`web/`, published at `https://<user>.github.io/<repo>/app/`) signs in with its own
client in the **same project**, so it can open the `tenure.json` the Mac app created
(`drive.file` access follows the project).

1. **Clients** -> Create client -> Application type **Web application**, name `Tenure web`.
2. **Authorized JavaScript origins**: `https://<user>.github.io`, and `http://localhost:5173`
   for `npm run dev`. No redirect URI: the token model uses a popup.
3. **Data Access** stays `drive.file` only.
4. Copy the client id into the GitHub repository: Settings -> Secrets and variables ->
   Actions -> **Variables** -> `GOOGLE_WEB_CLIENT_ID`. A web client id is public (it ships in the
   page), so it is a variable, not a secret; the repository itself keeps `temp`. For local
   runs, put `VITE_GOOGLE_CLIENT_ID=<id>` in the ignored `web/.env.local`.
5. Run the Pages workflow (push to `main` or run it by hand), open the web app, sign in, and
   check that your boards appear. See [WEB.md](WEB.md).

## Access model

- `drive.file` grants access only to files this app created. Other Drive content stays
  invisible to the app.
- Access follows the app's Cloud project, not the Mac: the same client id on another Mac finds
  the existing `tenure.json` and merges it.
- The refresh token is stored in the Keychain on each Mac (this device only, readable while
  the Mac is unlocked), never in the data file. The access token stays in memory.
- The web app gets no refresh token: an access token of about an hour, in the page's memory
  only. Each visit, and each hour, takes one click on "Sign in with Google".
- The file in Drive is plain JSON, not encrypted by the app.
- Revoke at any time in the Google account under Security -> Third-party access, or with Sign
  out in the app. The Mac and web clients are revoked separately.
