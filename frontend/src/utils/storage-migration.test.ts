import { beforeEach, describe, expect, it } from 'vitest'

import { currentKeyFor, migrateLegacyKeys } from './storage-migration'

function fill(storage: Storage, entries: Record<string, string>) {
  for (const [key, value] of Object.entries(entries)) {
    storage.setItem(key, value)
  }
}

beforeEach(() => {
  localStorage.clear()
  sessionStorage.clear()
})

describe('legacy storage keys', () => {
  it('maps every pre-rename prefix to its current key', () => {
    expect(currentKeyFor('math-notebook:token')).toBe('questrace:token')
    expect(currentKeyFor('math-notebook:list-view')).toBe('questrace:list-view')
    expect(currentKeyFor('notebook:appearance:v1')).toBe('questrace:appearance:v1')
    expect(currentKeyFor('questrace:token')).toBeNull()
    expect(currentKeyFor('unrelated')).toBeNull()
  })

  it('copies authentication and list preferences without deleting the old keys', () => {
    fill(localStorage, {
      'math-notebook:token': 'secret-token',
      'math-notebook:auth-user': '{"user_id":1,"username":"owner"}',
      'math-notebook:list-view': 'table',
    })
    expect(migrateLegacyKeys(localStorage).sort()).toEqual([
      'questrace:auth-user',
      'questrace:list-view',
      'questrace:token',
    ])
    expect(localStorage.getItem('questrace:token')).toBe('secret-token')
    expect(localStorage.getItem('questrace:auth-user')).toBe('{"user_id":1,"username":"owner"}')
    expect(localStorage.getItem('questrace:list-view')).toBe('table')
    expect(localStorage.getItem('math-notebook:token')).toBe('secret-token')
  })

  it('copies appearance preferences including the legacy appearance name', () => {
    localStorage.setItem('notebook:appearance:v1', '{"version":1,"preset":"paper"}')
    migrateLegacyKeys(localStorage)
    expect(localStorage.getItem('questrace:appearance:v1')).toBe('{"version":1,"preset":"paper"}')
    expect(localStorage.getItem('notebook:appearance:v1')).toBe('{"version":1,"preset":"paper"}')
  })

  it('copies drafts, including the discarded-analysis snapshot, from session storage', () => {
    fill(sessionStorage, {
      'math-notebook:draft': '{"chapter":"原章节"}',
      'math-notebook:draft:before-analysis': '{"chapter":"AI章节"}',
    })
    migrateLegacyKeys(sessionStorage)
    expect(sessionStorage.getItem('questrace:draft')).toBe('{"chapter":"原章节"}')
    expect(sessionStorage.getItem('questrace:draft:before-analysis')).toBe('{"chapter":"AI章节"}')
  })

  it('never overwrites a value already stored under the current key', () => {
    fill(localStorage, {
      'math-notebook:token': 'stale-token',
      'questrace:token': 'current-token',
    })
    expect(migrateLegacyKeys(localStorage)).toEqual([])
    expect(localStorage.getItem('questrace:token')).toBe('current-token')
  })
})
