# IntegrationTests

Test-only SPM target: `IntegrationTests`.

## Scope

Domain use cases against the real Persistence module.

## Tests

`SyncEndToEndTests` (1 test): two Macs with real `tenure.json` files converge through an
in-memory remote, and the uploaded file stays readable JSON.
