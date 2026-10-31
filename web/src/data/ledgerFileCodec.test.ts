import { describe, expect, it } from 'vitest'
import { fixture, fixtureBytes, fixtureText } from '../../test/fixtures'
import { LedgerError } from '../domain/errors'
import { ledgerFileCodec as codec } from './ledgerFileCodec'

interface DecodeCase {
  name: string
  input: string
  error?: string
}

const outcome = (input: string) => {
  try {
    codec.decode(input)
    return undefined
  } catch (error) {
    if (!(error instanceof LedgerError)) throw error
    const reason = error.reason
    return reason.kind === 'unsupportedFormatVersion'
      ? `${reason.kind}:${reason.version}`
      : reason.kind
  }
}

describe('ledgerFileCodec against the Swift codec', () => {
  it.each(['file-full.json', 'file-empty.json'])('round-trips %s byte for byte', (name) => {
    const snapshot = codec.decode(fixtureBytes(name))
    expect(codec.encode(snapshot)).toBe(fixtureText(name))
  })

  it('decodes malformed fields to the same values as the Mac', () => {
    const snapshot = codec.decode(fixtureBytes('tolerant-input.json'))
    expect(codec.encode(snapshot)).toBe(fixtureText('tolerant-output.json'))
  })

  it.each(fixture<DecodeCase[]>('decode-cases.json').map((c) => [c.name, c] as const))(
    'decode: %s',
    (_, decodeCase) => {
      expect(outcome(decodeCase.input)).toBe(decodeCase.error)
    },
  )
})

describe('ledgerFileCodec on its own', () => {
  it('refuses invalid UTF-8', () => {
    const bytes = new Uint8Array([0x7b, 0xff, 0x7d])
    expect(() => codec.decode(bytes)).toThrow(LedgerError)
  })

  it('gives a metric without a readable id a new one', () => {
    const file = fixtureText('file-empty.json')
      .replace(
        '"boards" : [\n\n  ]',
        '"boards" : [{"id": "00000000-0000-4000-8000-000000000001", "updatedAt": 1, "start": "2020-01"}]',
      )
      .replace(
        '"entries" : [\n\n  ]',
        '"entries" : [{"id": "00000000-0000-4000-8000-000000000002", "boardId": "00000000-0000-4000-8000-000000000001", "updatedAt": 1, "date": "2020-01-01", "metrics": [{"id": 5, "after": "1"}]}]',
      )
    const [entry] = codec.decode(file).entries
    expect(entry?.metrics[0]?.id).toMatch(/^[0-9A-F-]{36}$/)
  })

  it('falls back to the local day and month of updatedAt for a missing date', () => {
    const updatedAt = Date.UTC(2026, 2, 15, 12)
    const file = `{"format": "tenure", "version": 1,
      "boards": [{"id": "00000000-0000-4000-8000-000000000001", "updatedAt": ${updatedAt}}],
      "entries": [{"id": "00000000-0000-4000-8000-000000000002", "boardId": "00000000-0000-4000-8000-000000000001", "updatedAt": ${updatedAt}, "date": "20260-01-01"}]}`
    const snapshot = codec.decode(file)
    const local = new Date(updatedAt)
    expect(snapshot.boards[0]?.start).toEqual({
      year: local.getFullYear(),
      month: local.getMonth() + 1,
    })
    expect(snapshot.entries[0]?.date).toEqual({
      year: local.getFullYear(),
      month: local.getMonth() + 1,
      day: local.getDate(),
    })
  })

  it('refuses a stamp past the safe integer range rather than rounding it', () => {
    const file = `{"format": "tenure", "version": 1, "entries": [],
      "boards": [{"id": "00000000-0000-4000-8000-000000000001", "updatedAt": 9007199254740993}]}`
    expect(() => codec.decode(file)).toThrow(LedgerError)
  })
})
