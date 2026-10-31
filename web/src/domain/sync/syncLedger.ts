// Port of Packages/Domain/Sources/Sync/SyncLedger.swift. One sync round between the store
// and the remote copy:
//
// 1. Remote head unchanged since the last round: upload only if local changed.
// 2. Head changed: download, check, merge into the store, then upload the merged state
//    unless the remote already holds it.
// 3. After uploading, list revisions since the downloaded head. One from another device that
//    landed in between was overwritten: merge it and upload again (up to 3 attempts).
//
// Differences from the Mac, both deliberate: no remote file means `noRemoteFile` instead of
// creating one, and uploads are never pinned (the Mac keeps one pinned backup a day).
import { SyncError } from '../errors'
import { fingerprint } from '../fingerprint'
import type { LedgerStore } from '../ledgerStore'
import type { ClockPort, LedgerCodecPort, RemoteRevision, RemoteStorePort } from '../ports'
import { systemClock } from '../ports'
import type { Timestamp } from '../timestamp'
import { decodeRemote, mapping, rejectFutureStamps } from './remoteCheck'

/** What this page last agreed on with the remote copy. Kept in memory only. */
export interface SyncRecord {
  /** The remote revision whose content equals the local state at `syncedAt`. */
  readonly revision: RemoteRevision
  /** Fingerprint of that content: a different local fingerprint means changes to upload. */
  readonly fingerprint: bigint
  readonly syncedAt: Timestamp
}

export type SyncOutcome =
  /** Local and remote already held the same content. */
  | 'upToDate'
  /** Remote changes were merged in; nothing new to upload. */
  | 'pulled'
  /** Local changes (merged with any remote ones) were uploaded. */
  | 'pushed'

export const maxAttempts = 3

export class SyncLedger {
  private record: SyncRecord | undefined

  constructor(
    private readonly remote: RemoteStorePort,
    private readonly codec: LedgerCodecPort,
    private readonly clock: ClockPort = systemClock,
  ) {}

  /** The last agreed state; undefined before the first successful round. */
  lastRecord(): SyncRecord | undefined {
    return this.record
  }

  /** On sign-out: the next account starts from a fresh download and merge. */
  clear(): void {
    this.record = undefined
  }

  /** Throws `SyncError`. A failed round leaves the store as it was or with remote changes fully merged. */
  run(store: LedgerStore): Promise<SyncOutcome> {
    return mapping(() => this.round(store))
  }

  private async round(store: LedgerStore): Promise<SyncOutcome> {
    let base = await this.remote.head()
    if (base === undefined) throw new SyncError({ kind: 'noRemoteFile' })
    // Fingerprint of what `base` holds, when known without downloading it.
    let baseFingerprint = base === this.record?.revision ? this.record.fingerprint : undefined
    let pulled = false
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      if (baseFingerprint === undefined) {
        const result = await this.pull(base, store)
        pulled = pulled || result.changed
        baseFingerprint = result.fingerprint
      }
      const local = store.snapshot()
      const localFingerprint = fingerprint(local)
      if (localFingerprint === baseFingerprint) {
        this.remember(base, localFingerprint)
        return pulled ? 'pulled' : 'upToDate'
      }
      const uploaded = await this.remote.upload(this.codec.encode(local))
      const missed = (await this.remote.revisionsAfter(base)).filter((rev) => rev !== uploaded)
      if (missed.length === 0) {
        this.remember(uploaded, localFingerprint)
        return 'pushed'
      }
      // Another device uploaded between this round's download and upload, and this upload
      // replaced its content: merge what it wrote, then upload again over this one.
      for (const revision of missed) {
        await this.pull(revision, store)
      }
      base = uploaded
      baseFingerprint = localFingerprint
    }
    throw new SyncError({ kind: 'busy' })
  }

  /** Downloads one revision and merges it into the store. */
  private async pull(revision: RemoteRevision, store: LedgerStore) {
    const snapshot = decodeRemote(await this.remote.download(revision), this.codec)
    rejectFutureStamps(snapshot, this.clock.now())
    const changed = store.merge(snapshot)
    return { changed, fingerprint: fingerprint(snapshot) }
  }

  private remember(revision: RemoteRevision, fingerprint: bigint): void {
    this.record = { revision, fingerprint, syncedAt: this.clock.now() }
  }
}
