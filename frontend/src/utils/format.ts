const masteryStatusLabel: Record<string, string> = {
  unmastered: '未掌握',
  learning: '学习中',
  mastered: '已掌握',
}

const sourceTypeLabel: Record<string, string> = {
  manual: '手动录入',
  image: '图片识别',
  import: '导入',
}

export function formatMasteryStatus(value?: string): string {
  if (!value) {
    return '--'
  }
  return masteryStatusLabel[value] || value
}

export function formatSourceType(value?: string): string {
  if (!value) {
    return '--'
  }
  return sourceTypeLabel[value] || value
}

export function formatDateTime(value?: string): string {
  if (!value) {
    return '--'
  }

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return value
  }

  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

export function truncateText(value: string, length = 120): string {
  if (value.length <= length) {
    return value
  }

  return `${value.slice(0, length).trimEnd()}...`
}

export function formatBytes(value?: number): string {
  if (!value || value <= 0) {
    return '--'
  }

  const units = ['B', 'KB', 'MB', 'GB']
  let size = value
  let unitIndex = 0

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024
    unitIndex += 1
  }

  const digits = size >= 100 || unitIndex === 0 ? 0 : size >= 10 ? 1 : 2
  return `${size.toFixed(digits)} ${units[unitIndex]}`
}
