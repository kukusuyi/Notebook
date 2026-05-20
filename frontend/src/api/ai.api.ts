import { httpGet, httpPost } from './http'

import type {
  AIChapterListResponse,
  AIProviderListResponse,
  AIProviderModelListResponse,
  AnalyzeWrongQuestionPayload,
  AnalyzeWrongQuestionResponse,
} from '@/types/ai'
import type { OCRContext, QuestionJSON } from '@/types/question'

export function listAIModelProviders() {
  return httpGet<AIProviderListResponse>('/api/v1/ai/model-providers')
}

export function listAIChapters() {
  return httpGet<AIChapterListResponse>('/api/v1/ai/chapters')
}

export function listAIProviderModels(providerName: string) {
  return httpGet<AIProviderModelListResponse>(
    `/api/v1/ai/model-providers/${encodeURIComponent(providerName)}/models`,
  )
}

export function analyzeWrongQuestion(payload: AnalyzeWrongQuestionPayload) {
  return httpPost<AnalyzeWrongQuestionResponse>('/api/v1/ai/analyze-wrong-question', payload)
}

export function recognizeWrongQuestion(payload: { image_url: string; image_id: number }) {
  return httpPost<QuestionJSON & OCRContext>('/api/v1/ocr/wrong-question-json', payload, { timeout: 300000 })
}
