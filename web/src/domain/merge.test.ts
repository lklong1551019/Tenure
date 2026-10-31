import { describe, expect, it } from 'vitest'
import { fixture } from '../../test/fixtures'
import { ledgerFileCodec as codec } from '../data/ledgerFileCodec'
import { fingerprint } from './fingerprint'
import { merge } from './merge'

interface MergeCase {
  name: string
  now: number
  local: string
  remote: string
  merged: string
}

interface FingerprintCase {
  name: string
  file: string
  fingerprint: string
}

describe('merge against MergePolicy', () => {
  it.each(fixture<MergeCase[]>('merge-cases.json').map((c) => [c.name, c] as const))(
    '%s',
    (_, mergeCase) => {
      const local = codec.decode(mergeCase.local)
      const remote = codec.decode(mergeCase.remote)
      expect(codec.encode(merge(local, remote, mergeCase.now))).toBe(mergeCase.merged)
      expect(codec.encode(merge(remote, local, mergeCase.now))).toBe(mergeCase.merged)
    },
  )

  it('is idempotent', () => {
    for (const mergeCase of fixture<MergeCase[]>('merge-cases.json')) {
      const merged = codec.decode(mergeCase.merged)
      expect(codec.encode(merge(merged, merged, mergeCase.now))).toBe(mergeCase.merged)
    }
  })
})

describe('fingerprint against SnapshotFingerprint', () => {
  it.each(fixture<FingerprintCase[]>('fingerprint-cases.json').map((c) => [c.name, c] as const))(
    '%s',
    (_, fingerprintCase) => {
      expect(fingerprint(codec.decode(fingerprintCase.file)).toString()).toBe(
        fingerprintCase.fingerprint,
      )
    },
  )
})
