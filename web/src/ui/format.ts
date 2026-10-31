// How domain values read on screen. Dates follow the reader's language, as the Mac app's do;
// exports use fixed English names instead (domain/markdownExport.ts).
import type { DayDate, YearMonth } from '../domain/calendar'
import type { EntryType } from '../domain/model'
import type { StoryPart } from '../domain/story'

const dayFormat = new Intl.DateTimeFormat(undefined, {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
})
const monthFormat = new Intl.DateTimeFormat(undefined, { month: 'short', year: 'numeric' })

/** Noon, so no time zone moves it to another day. */
const noon = (year: number, month: number, day: number) => {
  const date = new Date(2000, month - 1, day, 12)
  date.setFullYear(year)
  return date
}

/** "12 Mar 2026" in the reader's language. */
export const shortDay = (day: DayDate) => dayFormat.format(noon(day.year, day.month, day.day))

/** "Jul 2017" in the reader's language. */
export const shortMonth = (month: YearMonth) => monthFormat.format(noon(month.year, month.month, 1))

/** Color family of a badge or tile; the same names as `Tint` in the Mac design system. */
export type Tint = 'neutral' | 'blue' | 'violet' | 'teal' | 'amber' | 'red'

/** The color of a task kind, by its stored name, so every view shows a kind alike. */
export function kindTint(type: EntryType): Tint {
  switch (type) {
    case 'product':
      return 'violet'
    case 'dev':
      return 'blue'
    case 'bugFix':
      return 'red'
    case 'findings':
      return 'amber'
    default:
      return 'neutral'
  }
}

export const storyTints: Record<StoryPart, Tint> = {
  problem: 'red',
  why: 'amber',
  solution: 'teal',
  impact: 'violet',
  difficulties: 'blue',
}

/**
 * The address a task's link opens, or undefined: only http and https, with a host and no
 * user name, as `AppModel.openLink` on the Mac. "jira/T-9" gets https:// in front.
 */
export function taskLinkUrl(link: string | undefined): string | undefined {
  const trimmed = link?.trim() ?? ''
  if (trimmed === '') return undefined
  return safeUrl(trimmed.includes('://') ? trimmed : `https://${trimmed}`)
}

/** `url` when it is http or https with a host and no credentials; undefined otherwise. */
export function safeUrl(text: string): string | undefined {
  let url: URL
  try {
    url = new URL(text)
  } catch {
    return undefined
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return undefined
  if (url.hostname === '' || url.username !== '' || url.password !== '') return undefined
  return url.href
}
