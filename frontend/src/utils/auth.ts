const TOKEN_KEY = 'math-notebook:token'
const AUTH_USER_KEY = 'math-notebook:auth-user'

export interface StoredAuthUser {
  user_id: number
  username: string
}

export function getAuthToken(): string {
  return window.localStorage.getItem(TOKEN_KEY) || ''
}

export function setAuthToken(token: string) {
  window.localStorage.setItem(TOKEN_KEY, token)
}

export function clearAuthToken() {
  window.localStorage.removeItem(TOKEN_KEY)
}

export function getStoredAuthUser(): StoredAuthUser | null {
  const raw = window.localStorage.getItem(AUTH_USER_KEY)
  if (!raw) {
    return null
  }

  try {
    return JSON.parse(raw) as StoredAuthUser
  } catch {
    window.localStorage.removeItem(AUTH_USER_KEY)
    return null
  }
}

export function setStoredAuthUser(user: StoredAuthUser) {
  window.localStorage.setItem(AUTH_USER_KEY, JSON.stringify(user))
}

export function clearStoredAuthUser() {
  window.localStorage.removeItem(AUTH_USER_KEY)
}

export function clearAuthState() {
  clearAuthToken()
  clearStoredAuthUser()
}
