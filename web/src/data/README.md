# data

The file format (`ledgerFileCodec`), the Drive REST client, and Google sign-in: ports of
`Packages/Data`. Imports `domain` only. `GoogleAuth` keeps the access token in memory and
never writes it anywhere.
