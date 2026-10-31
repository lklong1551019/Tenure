import { describe, expect, it } from 'vitest'
import { parseInline, plainText } from './inlineMarkdown'

describe('parseInline', () => {
  it('reads bold, italic, code, and links', () => {
    expect(parseInline('a **b** *c* `d` [e](https://x.example/e)')).toEqual([
      { kind: 'text', text: 'a ' },
      { kind: 'strong', children: [{ kind: 'text', text: 'b' }] },
      { kind: 'text', text: ' ' },
      { kind: 'emphasis', children: [{ kind: 'text', text: 'c' }] },
      { kind: 'text', text: ' ' },
      { kind: 'code', text: 'd' },
      { kind: 'text', text: ' ' },
      { kind: 'link', href: 'https://x.example/e', children: [{ kind: 'text', text: 'e' }] },
    ])
  })

  it('keeps only http and https links', () => {
    for (const href of [
      'javascript:alert(1)',
      'file:///etc/passwd',
      'tenure://x',
      'https://u:p@x.example',
    ]) {
      const [node] = parseInline(`[x](${href})`)
      expect(node).toEqual({
        kind: 'link',
        href: undefined,
        children: [{ kind: 'text', text: 'x' }],
      })
    }
  })

  it('reads the HTML tags people type as Markdown', () => {
    expect(plainText(parseInline('<b>bold</b><br>next'))).toBe('bold\nnext')
    expect(parseInline('<B>x</B>')[0]).toMatchObject({ kind: 'strong' })
  })

  it('never turns other HTML into markup', () => {
    expect(parseInline('<img src=x onerror=alert(1)>')).toEqual([
      { kind: 'text', text: '<img src=x onerror=alert(1)>' },
    ])
  })

  it('leaves stray markers and snake_case alone', () => {
    expect(plainText(parseInline('a * b, 2*3, snake_case_name, **open'))).toBe(
      'a * b, 2*3, snake_case_name, **open',
    )
  })

  it('keeps line breaks and spacing', () => {
    expect(plainText(parseInline('- one\n- two\n\n  three'))).toBe('- one\n- two\n\n  three')
  })
})
