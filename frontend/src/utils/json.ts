import type { QuestionJSON } from '@/types/question'

export function createEmptyQuestionJSON(): QuestionJSON {
  return {
    question_core: '',
    standard_solution: '',
    wrong_solution: '',
  }
}

export function formatQuestionJSON(value: QuestionJSON): string {
  return JSON.stringify(value, null, 2)
}

export function parseQuestionJSON(raw: string): QuestionJSON {
  const parsed = JSON.parse(raw) as Partial<QuestionJSON>

  if (typeof parsed !== 'object' || parsed === null) {
    throw new Error('JSON 内容必须是对象。')
  }

  if (typeof parsed.question_core !== 'string') {
    throw new Error('question_core 必须是字符串。')
  }

  return {
    question_core: parsed.question_core,
    standard_solution:
      typeof parsed.standard_solution === 'string' ? parsed.standard_solution : '',
    wrong_solution: typeof parsed.wrong_solution === 'string' ? parsed.wrong_solution : '',
  }
}
