export function getErrorMessage(error: unknown, fallback = '请求失败，请稍后重试。'): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message
  }

  return fallback
}
