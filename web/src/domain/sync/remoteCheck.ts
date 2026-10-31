// Port of Packages/Domain/Sources/Sync/RemoteLedgerCheck.swift: rules every remote copy
// passes before anything local changes. The remote file is untrusted input.
import { LedgerError, RemoteStoreError, SyncError } from '../errors'
import type { LedgerSnapshot } from '../model'
import type { LedgerCodecPort } from '../ports'
import { addDays, type Timestamp } from '../timestamp'

/** Clock skew tolerated between devices; a stamp further ahead would win every merge. */
export const maximumSkewDays = 1

export function decodeRemote(data: Uint8Array, codec: LedgerCodecPort): LedgerSnapshot {
  try {
    return codec.decode(data)
  } catch (error) {
    if (error instanceof LedgerError && error.reason.kind === 'unsupportedFormatVersion') {
      throw new SyncError({ kind: 'unsupportedRemote', version: error.reason.version })
    }
    throw new SyncError({ kind: 'corruptRemote' })
  }
}

export function rejectFutureStamps(snapshot: LedgerSnapshot, now: Timestamp): void {
  const limit = addDays(now, maximumSkewDays)
  const items = [...snapshot.boards, ...snapshot.entries]
  if (items.some((item) => item.updatedAt > limit)) {
    throw new SyncError({ kind: 'corruptRemote' })
  }
}

/** Transport errors become `SyncError` 'remote'; a `SyncError` passes through. */
export async function mapping<Value>(body: () => Promise<Value>): Promise<Value> {
  try {
    return await body()
  } catch (error) {
    if (error instanceof SyncError) throw error
    if (error instanceof RemoteStoreError) {
      throw new SyncError({ kind: 'remote', error: error.reason })
    }
    throw error
  }
}
