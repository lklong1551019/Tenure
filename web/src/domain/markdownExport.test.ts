import { describe, expect, it } from 'vitest'
import { fixture } from '../../test/fixtures'
import { ledgerFileCodec as codec } from '../data/ledgerFileCodec'
import { parseDayDate } from './calendar'
import {
  exportAll,
  exportBoard,
  exportEntry,
  exportYear,
  exportYears,
  fileName,
  type MarkdownOptions,
} from './markdownExport'
import { isDeleted } from './model'
import { metricChangeText, withUnit } from './story'

interface ExportFixture {
  file: string
  exportedOn: string
  exports: { name: string; markdown: string }[]
  years: number[]
  fileNames: { title: string; fileName: string }[]
  metrics: {
    before?: string
    after: string
    unit?: string
    changeText?: string
    afterWithUnit: string
  }[]
}

const data = fixture<ExportFixture>('export-cases.json')
const { boards, entries } = codec.decode(data.file)
const day = parseDayDate(data.exportedOn)!
const bare: MarkdownOptions = { story: false, metrics: false, linksAndTags: false }
const current = boards.find((board) => board.name.startsWith('Zalo'))!

/** The TS export for each case name the Swift test wrote. */
function produce(name: string): string {
  if (name === 'all') return exportAll(boards, entries, day)
  if (name === 'year 2026') return exportYear(2026, boards, entries, day)
  if (name === 'year 2026 one board, bare') {
    return exportYear(2026, boards, entries, day, bare, current.id)
  }
  if (name.startsWith('board ')) {
    const board = boards.find((b) => !isDeleted(b) && `board ${b.name}` === name)!
    return exportBoard(board, entries, day)
  }
  const entry = entries.find((e) => `entry ${e.id}` === name)!
  return exportEntry(entry)
}

describe('Markdown export against MarkdownExport', () => {
  it.each(data.exports.map((c) => [c.name, c] as const))('%s', (name, exportCase) => {
    expect(produce(name)).toBe(exportCase.markdown)
  })

  it('lists the same years', () => {
    expect(exportYears(entries)).toEqual(data.years)
  })

  it.each(data.fileNames.map((c) => [JSON.stringify(c.title), c] as const))(
    'file name %s',
    (_, fileNameCase) => {
      expect(fileName(fileNameCase.title)).toBe(fileNameCase.fileName)
    },
  )

  it.each(data.metrics.map((c) => [`${c.before} -> ${c.after}`, c] as const))(
    'metric %s',
    (_, metricCase) => {
      const metric = { id: 'm', label: 'm', ...metricCase }
      expect(metricChangeText(metric)).toBe(metricCase.changeText)
      expect(withUnit(metric, metric.after)).toBe(metricCase.afterWithUnit)
    },
  )
})
