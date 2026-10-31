// Port of Packages/Data/Persistence/Sources/LedgerFileCodec.swift. `tenure.json` is plain,
// pretty-printed JSON with sorted keys, byte for byte what the Mac writes:
//
//     { "format": "tenure", "version": 1, "boards": [...], "entries": [...] }
import { boardJson, decodeBoard, decodeEntry, entryJson, isObject } from '../domain/coding'
import { LedgerError } from '../domain/errors'
import { writeJson } from '../domain/jsonText'
import type { Board, Entry, LedgerSnapshot } from '../domain/model'
import type { LedgerCodecPort } from '../domain/ports'
import { compareOrdinal } from '../domain/text'

export const ledgerFormat = 'tenure'
export const currentVersion = 1

const byId = (lhs: Board | Entry, rhs: Board | Entry) => compareOrdinal(lhs.id, rhs.id)

// Invalid UTF-8 is a corrupt file, not text with replacement characters in it.
const decoder = new TextDecoder('utf-8', { fatal: true })

export const ledgerFileCodec: LedgerCodecPort = {
  encode(snapshot: LedgerSnapshot): string {
    return writeJson(
      {
        format: ledgerFormat,
        version: currentVersion,
        boards: [...snapshot.boards].sort(byId).map(boardJson),
        entries: [...snapshot.entries].sort(byId).map(entryJson),
      },
      'file',
    )
  },

  /**
   * Throws `LedgerError` 'unsupportedFormatVersion' for a newer file, and 'corruptFile' for
   * anything that is not a Tenure file or repeats an id.
   */
  decode(data: Uint8Array | string): LedgerSnapshot {
    const file = parse(data)
    if (!isObject(file) || file.format !== ledgerFormat || !Number.isSafeInteger(file.version)) {
      throw corrupt()
    }
    const version = file.version as number
    if (version > currentVersion) {
      throw new LedgerError({ kind: 'unsupportedFormatVersion', version })
    }
    if (!Array.isArray(file.boards) || !Array.isArray(file.entries)) throw corrupt()
    let boards: Board[]
    let entries: Entry[]
    try {
      boards = file.boards.map(decodeBoard)
      entries = file.entries.map(decodeEntry)
    } catch {
      throw corrupt()
    }
    if (hasDuplicateIds(boards) || hasDuplicateIds(entries)) throw corrupt()
    return { boards, entries }
  },
}

function parse(data: Uint8Array | string): unknown {
  try {
    return JSON.parse(typeof data === 'string' ? data : decoder.decode(data))
  } catch {
    throw corrupt()
  }
}

const corrupt = () => new LedgerError({ kind: 'corruptFile' })

const hasDuplicateIds = (items: readonly (Board | Entry)[]) =>
  new Set(items.map((item) => item.id)).size !== items.length
