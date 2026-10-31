import { useState } from 'react'

/**
 * A display setting kept in localStorage (grid or list, sort order). Never data: the ledger
 * and the token stay in memory. Storage that is unavailable or holds an unknown value falls
 * back to `initial`.
 */
export function usePreference<Value extends string>(
  key: string,
  initial: Value,
  allowed: readonly Value[],
): [Value, (value: Value) => void] {
  const storageKey = `tenure.${key}`
  const [value, setValue] = useState<Value>(() => {
    try {
      const stored = localStorage.getItem(storageKey)
      return allowed.includes(stored as Value) ? (stored as Value) : initial
    } catch {
      return initial
    }
  })
  const update = (next: Value) => {
    setValue(next)
    try {
      localStorage.setItem(storageKey, next)
    } catch {
      // Private mode or storage off: the setting lasts for this page only.
    }
  }
  return [value, update]
}
