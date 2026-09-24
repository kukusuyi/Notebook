// The Questrace rename changed every browser storage key. Values stored under
// the pre-rename keys are copied to the new keys on startup; the old keys are
// kept so that rolling back to an older build still finds its data.
const RENAMES: ReadonlyArray<readonly [prefix: string, replacement: string]> = [
  ['math-notebook:', 'questrace:'],
  ['notebook:', 'questrace:'],
]

export function currentKeyFor(key: string): string | null {
  const rename = RENAMES.find(([prefix]) => key.startsWith(prefix))
  return rename ? rename[1] + key.slice(rename[0].length) : null
}

/** Copies pre-rename entries of one storage area to their current keys. */
export function migrateLegacyKeys(storage: Storage): string[] {
  const pending: Array<[key: string, value: string]> = []
  for (let index = 0; index < storage.length; index += 1) {
    const key = storage.key(index)
    if (key === null) {
      continue
    }

    const current = currentKeyFor(key)
    if (current === null) {
      continue
    }

    // A value already written under the current key always wins.
    const value = storage.getItem(key)
    if (value !== null && storage.getItem(current) === null) {
      pending.push([current, value])
    }
  }

  for (const [key, value] of pending) {
    try {
      storage.setItem(key, value)
    } catch {
      // Private browsing can reject writes; the old key still holds the data.
    }
  }
  return pending.map(([key]) => key)
}

export function migrateLegacyStorage() {
  for (const area of [window.localStorage, window.sessionStorage]) {
    try {
      migrateLegacyKeys(area)
    } catch {
      // Storage can be unavailable entirely; the app then starts with defaults.
    }
  }
}

// Runs while this module is imported, before the appearance module reads the
// preferences it persisted.
migrateLegacyStorage()
