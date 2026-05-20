import { httpGet } from './http'

import type {
  DashboardRecentResponse,
  DashboardSummaryResponse,
  DashboardTagsResponse,
} from '@/types/dashboard'

export function getDashboardSummary() {
  return httpGet<DashboardSummaryResponse>('/api/v1/dashboard/summary')
}

export function getDashboardRecentQuestions(limit = 4) {
  return httpGet<DashboardRecentResponse>('/api/v1/dashboard/recent', { limit })
}

export function getDashboardTopTags(limit = 6) {
  return httpGet<DashboardTagsResponse>('/api/v1/dashboard/tags', { limit })
}
