import { defineStore } from 'pinia'
import { ref } from 'vue'

import type { QuestionListItem } from '@/types/question'

export const useQuestionStore = defineStore('question', () => {
  const recentQuestions = ref<QuestionListItem[]>([])
  const preferredListView = ref<'card' | 'table'>(
    (window.localStorage.getItem('math-notebook:list-view') as 'card' | 'table') || 'card',
  )

  function setRecentQuestions(items: QuestionListItem[]) {
    recentQuestions.value = items
  }

  function setPreferredListView(mode: 'card' | 'table') {
    preferredListView.value = mode
    window.localStorage.setItem('math-notebook:list-view', mode)
  }

  return {
    recentQuestions,
    preferredListView,
    setRecentQuestions,
    setPreferredListView,
  }
})
