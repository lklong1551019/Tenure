// Ports of LedgerError (Store/LedgerError.swift) and the sync errors (Sync/SyncTypes.swift).
// Each is a class with a `kind`, so a `switch` over it is checked for exhaustiveness.

export type LedgerErrorKind =
  | { kind: 'unsupportedFormatVersion'; version: number }
  /** Not a Tenure file, or not valid JSON. */
  | { kind: 'corruptFile' }
  | { kind: 'notFound' }

export class LedgerError extends Error {
  constructor(readonly reason: LedgerErrorKind) {
    super(`ledger: ${reason.kind}`)
    this.name = 'LedgerError'
  }
}

/** Failures of the cloud transport. The local data is never affected. */
export type RemoteStoreErrorKind =
  /** No token, or Google refused it: the user has to sign in again. */
  | { kind: 'signedOut' }
  | { kind: 'offline' }
  | { kind: 'rateLimited' }
  | { kind: 'server'; status: number }
  | { kind: 'notFound' }

export class RemoteStoreError extends Error {
  constructor(readonly reason: RemoteStoreErrorKind) {
    super(`remote: ${reason.kind}`)
    this.name = 'RemoteStoreError'
  }
}

/** Why a sync round stopped. Nothing local changes when one is thrown. */
export type SyncErrorKind =
  /** The remote file was written by a newer build. */
  | { kind: 'unsupportedRemote'; version: number }
  /** The remote file does not decode, or carries stamps far in the future. */
  | { kind: 'corruptRemote' }
  /** Another device kept uploading during every attempt; the next round retries. */
  | { kind: 'busy' }
  /**
   * Web only: there is no `tenure.json` in this Drive. The web never creates one, so it can
   * never split the data into two files; the Mac app creates it on its first sync.
   */
  | { kind: 'noRemoteFile' }
  | { kind: 'remote'; error: RemoteStoreErrorKind }

export class SyncError extends Error {
  constructor(readonly reason: SyncErrorKind) {
    super(`sync: ${reason.kind}`)
    this.name = 'SyncError'
  }
}
