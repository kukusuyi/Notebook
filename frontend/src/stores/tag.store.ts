import { defineStore } from 'pinia'
import { computed, ref } from 'vue'

import { listTags } from '@/api/tag.api'
import type { TagItem } from '@/types/tag'

export const useTagStore = defineStore('tag', () => {
  const tags = ref<TagItem[]>([])
  const loading = ref(false)

  const groupedOptions = computed(() => ({
    knowledge_points: tags.value
      .filter((item) => item.tag_type === 'knowledge_point')
      .map((item) => item.tag_name),
    problem_type: tags.value
      .filter((item) => item.tag_type === 'problem_type')
      .map((item) => item.tag_name),
    method: tags.value.filter((item) => item.tag_type === 'method').map((item) => item.tag_name),
    mistake_reason: tags.value
      .filter((item) => item.tag_type === 'mistake_reason')
      .map((item) => item.tag_name),
  }))

  async function fetchTags(params?: { tag_type?: string; keyword?: string }) {
    loading.value = true
    try {
      const response = await listTags(params)
      tags.value = response.list
      return response.list
    } finally {
      loading.value = false
    }
  }

  return {
    tags,
    loading,
    groupedOptions,
    fetchTags,
  }
})
