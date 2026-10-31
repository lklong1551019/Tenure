// Ports of Packages/Domain/Sources/Ports. The domain talks to the outside only through these.
import type { LedgerSnapshot } from './model'
import type { Timestamp } from './timestamp'

/** The file format, shared by every copy. Decoding refuses a newer format version. */
export interface LedgerCodecPort {
  encode(snapshot: LedgerSnapshot): string
  /** Throws `LedgerError`. */
  decode(data: Uint8Array | string): LedgerSnapshot
}

/** One version of the remote file. Opaque; compared for equality only. */
export type RemoteRevision = string

/** The data file in cloud storage. Throws `RemoteStoreError`. */
export interface RemoteStorePort {
  /** The newest revision, without downloading; undefined when no remote copy exists. */
  head(): Promise<RemoteRevision | undefined>
  download(revision: RemoteRevision): Promise<Uint8Array>
  /** Replaces the remote content. The web never creates the file and never pins. */
  upload(data: string): Promise<RemoteRevision>
  /** Revisions newer than `revision`, oldest first, the head included. */
  revisionsAfter(revision: RemoteRevision): Promise<RemoteRevision[]>
}

export interface ClockPort {
  now(): Timestamp
}

export const systemClock: ClockPort = { now: () => Date.now() }
