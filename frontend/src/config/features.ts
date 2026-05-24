function parseBooleanEnv(rawValue: unknown, defaultValue = false): boolean {
  if (typeof rawValue !== 'string') {
    return defaultValue
  }

  const value = rawValue.trim().toLowerCase()
  if (!value) {
    return defaultValue
  }

  if (['1', 'true', 'yes', 'on'].includes(value)) {
    return true
  }

  if (['0', 'false', 'no', 'off'].includes(value)) {
    return false
  }

  return defaultValue
}

export const settingsPageEnabled = parseBooleanEnv(
  import.meta.env.VITE_ENABLE_SETTINGS_PAGE,
  false,
)
