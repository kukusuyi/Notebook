export type TagType = 'knowledge_point' | 'problem_type' | 'method' | 'mistake_reason'

export interface TagItem {
  tag_id: number
  tag_name: string
  tag_type: TagType
  usage_count: number
  is_active: boolean
}

export interface TagListResponse {
  list: TagItem[]
}

export interface CreateTagPayload {
  tag_name: string
  tag_type: TagType
}
