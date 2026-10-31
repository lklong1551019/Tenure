// Port of Packages/Domain/Sources/Export/MarkdownExport.swift. Plain Markdown for a CV or a
// review: one board, one year, everything, or one task. Boards come newest first; tasks
// within a board oldest first, so they read as a story. Dates use English month names, so the
// file is the same everywhere.
import { compareDayDate, type DayDate, type YearMonth } from './calendar'
import {
  type Board,
  type Entry,
  entryTypeTitle,
  isDeleted,
  timelineOrder,
  type Uuid,
} from './model'
import {
  boardPeriod,
  counted,
  displayName,
  entryPeriod,
  entryYears,
  metricChangeText,
  story,
  storyPartTitles,
  touches,
  withUnit,
} from './story'
import { compareNames, lines, trimmingWhitespace, trimmingWhitespaceAndNewlines } from './text'

/** What an export includes besides each task's name, kind, and date. */
export interface MarkdownOptions {
  /** Problem, why, solution, impact, difficulties. */
  readonly story: boolean
  readonly metrics: boolean
  readonly linksAndTags: boolean
}

export const fullOptions: MarkdownOptions = { story: true, metrics: true, linksAndTags: true }

interface Group {
  readonly board: Board
  readonly entries: readonly Entry[]
}

/** `# Board`, its period, then each task as `##`. */
export function exportBoard(
  board: Board,
  entries: readonly Entry[],
  exportedOn: DayDate,
  options = fullOptions,
): string {
  const tasks = chronological(entries.filter((e) => e.boardId === board.id && !isDeleted(e)))
  const out = [
    `# ${inline(board.name)}`,
    '',
    `${boardPeriod(board, formatMonth)} · ${counted(tasks.length, 'task')}`,
    '',
    `Exported from Tenure on ${formatDay(exportedOn)}.`,
  ]
  for (const entry of tasks) {
    out.push('', ...entryLines(entry, 2, options))
  }
  return finish(out)
}

/** `# Year`, then each board with tasks in that year as `##`, its tasks as `###`. */
export function exportYear(
  year: number,
  boards: readonly Board[],
  entries: readonly Entry[],
  exportedOn: DayDate,
  options = fullOptions,
  boardId?: Uuid,
): string {
  return grouped(String(year), yearGroups(year, boards, entries, boardId), options, exportedOn)
}

/** Every board, newest first, as `##` under `# Tenure`, its tasks as `###`. */
export function exportAll(
  boards: readonly Board[],
  entries: readonly Entry[],
  exportedOn: DayDate,
  options = fullOptions,
): string {
  const groups = boards
    .filter((board) => !isDeleted(board))
    .sort(timelineOrder)
    .map((board) => ({
      board,
      entries: chronological(entries.filter((e) => e.boardId === board.id && !isDeleted(e))),
    }))
  return grouped('Tenure', groups, options, exportedOn)
}

/** One task as `#`, for the clipboard. */
export function exportEntry(entry: Entry, options = fullOptions): string {
  return finish(entryLines(entry, 1, options))
}

/** Tasks that `exportYear` would include, per board; boards with none are left out. */
export function yearGroups(
  year: number,
  boards: readonly Board[],
  entries: readonly Entry[],
  boardId?: Uuid,
): Group[] {
  return boards
    .filter((board) => !isDeleted(board) && (boardId === undefined || board.id === boardId))
    .sort(timelineOrder)
    .flatMap((board) => {
      const tasks = entries.filter(
        (e) => e.boardId === board.id && !isDeleted(e) && touches(e, year),
      )
      return tasks.length === 0 ? [] : [{ board, entries: chronological(tasks) }]
    })
}

/** Years with at least one task, newest first. */
export function exportYears(entries: readonly Entry[]): number[] {
  const years = new Set(entries.filter((e) => !isDeleted(e)).flatMap(entryYears))
  return [...years].sort((lhs, rhs) => rhs - lhs)
}

/** `CharacterSet.controlCharacters` (Cc and Cf), newlines, and characters file systems refuse. */
// eslint-disable-next-line no-control-regex -- matching control characters is the point
const unsafeFileCharacter = /[/\\:?*"<>|\p{Cc}\p{Cf}\n\r\u000B\u000C\u0085\u2028\u2029]/gu

/** "Zalo", "Tenure 2026": a file name, without the extension, safe on any file system. */
export function fileName(title: string): string {
  const cleaned = trimmingWhitespace(title.replace(unsafeFileCharacter, '-'))
  return cleaned === '' ? 'Tenure' : cleaned
}

function grouped(
  title: string,
  groups: readonly Group[],
  options: MarkdownOptions,
  exportedOn: DayDate,
): string {
  const total = groups.reduce((sum, group) => sum + group.entries.length, 0)
  const out = [
    `# ${title}`,
    '',
    `Exported from Tenure on ${formatDay(exportedOn)}. ${counted(total, 'task')} from ${counted(groups.length, 'board')}.`,
  ]
  for (const group of groups) {
    out.push('', `## ${inline(group.board.name)}`, '', boardPeriod(group.board, formatMonth))
    for (const entry of group.entries) {
      out.push('', ...entryLines(entry, 3, options))
    }
  }
  return finish(out)
}

export function entryLines(entry: Entry, level: number, options: MarkdownOptions): string[] {
  const out = [`${'#'.repeat(level)} ${inline(displayName(entry))}`, '']
  const facts = [entryTypeTitle(entry.type), entryPeriod(entry, formatDay)]
  const link = entry.link === undefined ? '' : trimmingWhitespace(entry.link)
  if (options.linksAndTags && link !== '') {
    facts.push(link.includes('://') ? `<${link}>` : inline(link))
  }
  out.push(facts.join(' · '))
  if (options.linksAndTags && entry.tags.length > 0) {
    out.push('', 'Tags: ' + entry.tags.map(inline).join(', '))
  }
  if (options.story) {
    for (const { part, text } of story(entry)) {
      out.push('', `**${storyPartTitles[part]}**`, '', trimmingWhitespaceAndNewlines(text))
    }
  }
  if (options.metrics && entry.metrics.length > 0) {
    out.push('', '| Metric | Before | After | Change | Note |', '|---|---|---|---|---|')
    for (const metric of entry.metrics) {
      const cells = [
        metric.label,
        metric.before === undefined ? '' : withUnit(metric, metric.before),
        withUnit(metric, metric.after),
        metricChangeText(metric) ?? '',
        metric.note ?? '',
      ]
      out.push('| ' + cells.map(cell).join(' | ') + ' |')
    }
  }
  return out
}

const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

/** "12 Mar 2026". */
export const formatDay = (day: DayDate) => `${day.day} ${months[day.month - 1]} ${day.year}`

/** "Mar 2026". */
export const formatMonth = (month: YearMonth) => `${months[month.month - 1]} ${month.year}`

function chronological(entries: readonly Entry[]): Entry[] {
  return [...entries].sort(
    (lhs, rhs) => compareDayDate(lhs.date, rhs.date) || compareNames(lhs.name, rhs.name),
  )
}

/** One line of text: newlines would break a heading or a list. */
const inline = (text: string) => trimmingWhitespace(lines(text).join(' '))

/** A table cell: one line, pipes escaped. */
const cell = (text: string) => inline(text).replaceAll('|', '\\|')

const finish = (out: readonly string[]) => out.join('\n') + '\n'
