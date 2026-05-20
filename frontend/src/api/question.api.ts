import { getApiBaseURL, httpDelete, httpGet, httpPost, httpPut } from './http'

import type {
  CreateWrongQuestionPayload,
  CreateWrongQuestionResponse,
  DeleteWrongQuestionResponse,
  ListQuestionFilter,
  QuestionDetail,
  QuestionPageResult,
  SimilarByJSONPayload,
  SimilarQuestionRequest,
  SimilarQuestionResponse,
  UpdateWrongQuestionPayload,
  UpdateWrongQuestionResponse,
} from '@/types/question'
import { getAuthToken } from '@/utils/auth'

export type QuestionExportMode = 'with_answers' | 'questions_only'

export function listQuestions(params: ListQuestionFilter) {
  return httpGet<QuestionPageResult>('/api/v1/wrong-questions', params)
}

export function getQuestionDetail(questionID: number) {
  return httpGet<QuestionDetail>(`/api/v1/wrong-questions/${questionID}`)
}

export function createQuestion(payload: CreateWrongQuestionPayload) {
  return httpPost<CreateWrongQuestionResponse>('/api/v1/wrong-questions', payload)
}

export function updateQuestion(questionID: number, payload: UpdateWrongQuestionPayload) {
  return httpPut<UpdateWrongQuestionResponse>(`/api/v1/wrong-questions/${questionID}`, payload)
}

export function deleteQuestion(questionID: number) {
  return httpDelete<DeleteWrongQuestionResponse>(`/api/v1/wrong-questions/${questionID}`)
}

export function findSimilarQuestions(questionID: number, payload: SimilarQuestionRequest) {
  return httpPost<SimilarQuestionResponse>(
    `/api/v1/wrong-questions/${questionID}/similar`,
    payload,
  )
}

export function findSimilarByJSON(payload: SimilarByJSONPayload) {
  return httpPost<SimilarQuestionResponse>('/api/v1/wrong-questions/similar-by-json', payload)
}

export function buildQuestionExportPrintURL(
  questionIDs: number[],
  exportMode: QuestionExportMode = 'with_answers',
) {
  const params = new URLSearchParams()
  params.set('question_ids', questionIDs.join(','))
  params.set('export_mode', exportMode)

  const token = getAuthToken()
  if (token) {
    params.set('access_token', token)
  }

  return `${getApiBaseURL()}/api/v1/wrong-questions/export/print?${params.toString()}`
}
