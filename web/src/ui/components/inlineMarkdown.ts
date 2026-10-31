// Story text as shown: inline Markdown (**bold**, *italic*, `code`, [links](https://...)),
// whitespace and line breaks kept, as `StoryText` on the Mac. The HTML tags people type by
// habit (<b>, <i>, <code>, <br>) are read as their Markdown twins. The result is a tree of
// plain values that React renders as text: nothing here ever becomes HTML.
import { safeUrl } from '../format'

export type InlineNode =
  | { kind: 'text'; text: string }
  | { kind: 'strong' | 'emphasis'; children: InlineNode[] }
  | { kind: 'code'; text: string }
  /** `href` is undefined for a link that is not http or https: it shows as its text only. */
  | { kind: 'link'; href: string | undefined; children: InlineNode[] }

const htmlTwins: [RegExp, string][] = [
  [/<\/?(b|strong)>/gi, '**'],
  [/<\/?(i|em)>/gi, '*'],
  [/<\/?code>/gi, '`'],
  [/<br\s*\/?>/gi, '\n'],
]

export function parseInline(source: string): InlineNode[] {
  const text = htmlTwins.reduce(
    (value, [pattern, markdown]) => value.replace(pattern, markdown),
    source,
  )
  return parse(text)
}

function parse(text: string): InlineNode[] {
  const nodes: InlineNode[] = []
  let plain = ''
  const flush = () => {
    if (plain !== '') nodes.push({ kind: 'text', text: plain })
    plain = ''
  }
  let index = 0
  while (index < text.length) {
    const rest = text.slice(index)
    const char = text[index] as string

    // A backslash escapes the punctuation Markdown would read.
    if (char === '\\' && /^\\[\\`*_[\]()]/.test(rest)) {
      plain += rest[1]
      index += 2
      continue
    }
    if (char === '`') {
      const end = text.indexOf('`', index + 1)
      if (end > index + 1) {
        flush()
        nodes.push({ kind: 'code', text: text.slice(index + 1, end) })
        index = end + 1
        continue
      }
    }
    if (char === '[') {
      const link = /^\[([^\]]+)\]\(([^)\s]+)\)/.exec(rest)
      if (link) {
        flush()
        const [whole, label = '', href = ''] = link
        nodes.push({ kind: 'link', href: safeUrl(href), children: parse(label) })
        index += whole.length
        continue
      }
    }
    if (char === '*' || char === '_') {
      const marker = rest.startsWith(char.repeat(2)) ? char.repeat(2) : char
      const end = closing(text, index + marker.length, marker)
      if (end !== -1) {
        flush()
        nodes.push({
          kind: marker.length === 2 ? 'strong' : 'emphasis',
          children: parse(text.slice(index + marker.length, end)),
        })
        index = end + marker.length
        continue
      }
    }
    plain += char
    index++
  }
  flush()
  return nodes
}

/** Where `marker` closes a span opened just before `from`; -1 when it never does. */
function closing(text: string, from: number, marker: string): number {
  // An opening marker must touch its text: "a * b" is not emphasis.
  if (from >= text.length || /\s/.test(text[from] as string)) return -1
  for (let index = from + 1; index <= text.length - marker.length; index++) {
    const before = text[index - 1] as string
    if (text.startsWith(marker, index) && !/\s/.test(before)) {
      // A marker inside a run such as `**` does not end a single `*` span, and a `_` inside
      // a word is a letter.
      if (marker.length === 1 && (text[index + 1] === marker || before === marker)) {
        index++
        continue
      }
      if (marker === '_' && /\w/.test(text[index + 1] ?? '')) continue
      return index
    }
  }
  return -1
}

/** The text alone, for a card's one-line excerpt. */
export function plainText(nodes: readonly InlineNode[]): string {
  return nodes
    .map((node) =>
      node.kind === 'text' || node.kind === 'code' ? node.text : plainText(node.children),
    )
    .join('')
}
