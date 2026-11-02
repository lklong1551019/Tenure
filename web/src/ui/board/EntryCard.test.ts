import { describe, expect, it } from 'vitest'
import { linkParts } from './EntryCard'

describe('linkParts', () => {
  it('keeps the last path part whole', () => {
    expect(linkParts('https://jira.example.com/browse/PLA-6165')).toEqual([
      'https://jira.example.com/browse/',
      'PLA-6165',
    ])
  })

  it('keeps at most 16 characters of a long last part', () => {
    const [head, tail] = linkParts('https://example.com/a-very-long-final-segment-name')
    expect(tail).toBe('nal-segment-name')
    expect(head + tail).toBe('https://example.com/a-very-long-final-segment-name')
  })

  it('reads a trailing slash as part of the last part', () => {
    expect(linkParts('https://example.com/docs/')).toEqual(['https://example.com/', 'docs/'])
  })

  it('splits a link without a slash by length', () => {
    expect(linkParts('jira/T-9')).toEqual(['jira/', 'T-9'])
    expect(linkParts('short')).toEqual(['', 'short'])
  })
})
