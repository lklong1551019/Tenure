// The two layouts Swift's JSONEncoder writes for this app, reproduced byte for byte:
//
// - file:      [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes], for tenure.json
//              (LedgerFileCodec): two-space indent, `"key" : value`, an empty array as
//              "[\n\n<indent>]".
// - canonical: [.sortedKeys], for merge tie-breaks (MergePolicy.canonical): no whitespace,
//              and "/" escaped as "\/".
//
// JSON.stringify cannot be told either layout, so objects and arrays are written here; only
// strings go through it, since its escapes match Swift's (\b \f \n \r \t, other controls as
// \u00xx lowercase, everything else as UTF-8).

export type JsonValue =
  | string
  | number
  | boolean
  | null
  | readonly JsonValue[]
  | { readonly [key: string]: JsonValue | undefined }

export type JsonLayout = 'file' | 'canonical'

export function writeJson(value: JsonValue, layout: JsonLayout): string {
  return write(value, layout, 0)
}

function write(value: JsonValue, layout: JsonLayout, depth: number): string {
  if (value === null) return 'null'
  switch (typeof value) {
    case 'string':
      return layout === 'canonical'
        ? JSON.stringify(value).replaceAll('/', '\\/')
        : JSON.stringify(value)
    case 'number':
      if (!Number.isFinite(value)) throw new RangeError('JSON has no non-finite numbers')
      return String(value)
    case 'boolean':
      return String(value)
  }
  const pretty = layout === 'file'
  const inner = pretty ? '\n' + '  '.repeat(depth + 1) : ''
  const outer = pretty ? '\n' + '  '.repeat(depth) : ''
  if (Array.isArray(value)) {
    if (value.length === 0) return pretty ? `[\n${outer}]` : '[]'
    const items = value.map((item) => inner + write(item, layout, depth + 1))
    return `[${items.join(',')}${outer}]`
  }
  const object = value as { readonly [key: string]: JsonValue | undefined }
  // Swift leaves out a nil optional rather than writing null.
  const keys = Object.keys(object)
    .filter((key) => object[key] !== undefined)
    .sort((lhs, rhs) => (lhs < rhs ? -1 : lhs > rhs ? 1 : 0))
  if (keys.length === 0) return pretty ? `{\n${outer}}` : '{}'
  const separator = pretty ? ' : ' : ':'
  const members = keys.map(
    (key) =>
      inner + JSON.stringify(key) + separator + write(object[key] as JsonValue, layout, depth + 1),
  )
  return `{${members.join(',')}${outer}}`
}
