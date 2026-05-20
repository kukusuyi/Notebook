import type { QuestionListItem } from './question'
import type { TagItem } from './tag'

export interface DashboardDistributionItem {
  type: string
  count: number
}

export interface DashboardSummaryResponse {
  total_questions: number
  today_added: number
  unmastered_count: number
  image_bound_count: number
  active_tag_count: number
  mastery_distribution: DashboardDistributionItem[]
  source_distribution: DashboardDistributionItem[]
}

export interface DashboardRecentResponse {
  list: QuestionListItem[]
}

export interface DashboardTagsResponse {
  knowledge_points: TagItem[]
  mistake_reasons: TagItem[]
}
