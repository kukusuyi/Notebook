export interface ApiEnvelope<T> {
  code: number
  message: string
  data: T
}

export interface PageResult<T> {
  list: T[]
  total: number
  page: number
  page_size: number
}

export type SourceType = 'manual' | 'image' | 'import'
export type MasteryStatus = 'unmastered' | 'learning' | 'mastered'
export type SimilarityType = 'tag' | 'semantic' | 'mistake' | 'hybrid'
export type VectorType = 'semantic' | 'mistake'
export type OCRConfidence = 'high' | 'medium' | 'low'
export type DraftFlowMode = 'manual' | 'upload'
export type DraftStatus =
  | 'draft'
  | 'image_uploaded'
  | 'ocr_processing'
  | 'ocr_reviewing'
  | 'ai_processing'
  | 'ai_reviewing'
  | 'saved'
  | 'vector_pending'
  | 'vector_ready'
  | 'vector_failed'

export interface OptionItem<T = string> {
  label: string
  value: T
}
