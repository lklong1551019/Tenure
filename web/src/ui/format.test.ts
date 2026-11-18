import { describe, expect, it } from 'vitest'
import { linkLabel } from './format'

// The same cases as `linkLabelShowsTheTicketKeyOrTheHost` in the Mac's BoardFeatureTests.
describe('linkLabel', () => {
  it('shows the ticket key a link ends in', () => {
    expect(linkLabel('https://jira.example.com/browse/PLA-6165')).toBe('PLA-6165')
    expect(linkLabel(' https://jira.example.com/browse/PLA-6165?focused=1#c2 ')).toBe('PLA-6165')
    expect(linkLabel('jira/T-9')).toBe('T-9')
  })

  it('shows the host and the last path part otherwise', () => {
    expect(linkLabel('https://github.com/owner/repo/pull/12')).toBe('github.com · 12')
    expect(linkLabel('https://www.example.com/blog/post-12/')).toBe('example.com · post-12')
    expect(linkLabel('https://example.com')).toBe('example.com')
  })

  it('keeps a link without a scheme as written', () => {
    expect(linkLabel('example.com/notes')).toBe('example.com/notes')
  })
})
