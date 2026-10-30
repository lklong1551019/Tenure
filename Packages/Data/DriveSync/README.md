# DriveSync

Layer: data. SPM target: `DriveSync`.

## Scope

Google sign-in and the remote copy of `tenure.json` in Google Drive.

## Owns

- `GoogleAuth` (`DriveAccountPort`): OAuth with PKCE through `ASWebAuthenticationSession`,
  scope `drive.file` only; refresh token in the Keychain, access token in memory
- `DriveClient` (`RemoteStorePort`): Drive REST v3. One file in a "Tenure" folder, both found
  by an `appProperties` marker (`tnRole`), never by name; revisions, pinning
- `HTTPTransport`: retries with backoff, maps failures to `RemoteStoreError`

## Must not

- Decode or merge the ledger; bytes pass through unchanged
- Log tokens or file contents

## Depends on

Domain

## Tests

`DriveSyncTests` (26 tests): sign-in flow, refresh, revoke, file lookup and creation,
uploads, revisions, pinning, dev namespace, error mapping. A scripted `FakeHTTP`; no network.
