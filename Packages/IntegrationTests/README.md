# IntegrationTests

Test-only SPM target: `IntegrationTests`.

## Scope

Domain use cases against the real Persistence module, and the fixtures the web app's tests
read (`web/test/fixtures`).

## Tests

`SyncEndToEndTests` (1 test): two Macs with real `tenure.json` files converge through an
in-memory remote, and the uploaded file stays readable JSON.

`WebFixtureTests` (7 tests): the codec, merge, fingerprint, query, search, and export results
match `web/test/fixtures`. `TENURE_WRITE_FIXTURES=1` rewrites them; see `docs/WEB.md`.
