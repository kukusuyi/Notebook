<template>
  <article class="question-card paper-card">
    <div class="card-top">
      <div>
        <div class="card-meta">
          <span>{{ item.subject || '未分类学科' }}</span>
          <span v-if="item.chapter">· {{ item.chapter }}</span>
          <span>· 难度 {{ item.difficulty_level }}</span>
        </div>
        <h3 class="card-title">{{ truncateText(item.question_core, 120) }}</h3>
      </div>
      <div class="card-side">
        <el-checkbox
          :model-value="selected"
          class="select-box"
          @change="emit('toggle-select')"
        />
        <div class="card-badges">
        <span class="tag-pill badge">{{ formatMasteryStatus(item.mastery_status) }}</span>
        <span v-if="item.source_image_url" class="tag-pill badge">有原图</span>
        </div>
      </div>
    </div>

    <TagGroup :tags="item.tags" @tag-click="handleTagClick" />

    <div class="card-footer">
      <span class="meta-text">创建于 {{ formatDateTime(item.created_at) }}</span>
      <div class="card-actions">
        <RouterLink :to="`/questions/${item.question_id}`">
          <el-button text>详情</el-button>
        </RouterLink>
        <RouterLink :to="`/questions/${item.question_id}/edit`">
          <el-button text>编辑</el-button>
        </RouterLink>
      </div>
    </div>
  </article>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'

import TagGroup from '@/components/TagGroup/index.vue'
import type { QuestionListItem } from '@/types/question'
import { formatDateTime, formatMasteryStatus, truncateText } from '@/utils/format'

const props = defineProps<{
  item: QuestionListItem
  selected?: boolean
}>()

const emit = defineEmits<{
  (event: 'toggle-select'): void
}>()

const router = useRouter()

function handleTagClick(payload: { type: string; name: string }) {
  router.push({
    path: '/questions',
    query: {
      tagType: payload.type,
      tagName: payload.name,
    },
  })
}
</script>

<style scoped>
.question-card {
  display: grid;
  gap: 16px;
  padding: 20px;
}

.card-top {
  display: flex;
  justify-content: space-between;
  gap: 16px;
}

.card-meta {
  color: var(--text-secondary);
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.card-title {
  margin: 10px 0 0;
  font-size: 18px;
  line-height: 1.5;
}

.card-side,
.card-badges {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.card-side {
  align-items: flex-end;
  flex-direction: column;
}

.select-box {
  margin-right: -6px;
}

.badge {
  background: rgba(31, 41, 55, 0.06);
  border-color: rgba(31, 41, 55, 0.08);
}

.card-footer {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: center;
  flex-wrap: wrap;
}

.card-actions {
  display: flex;
  gap: 6px;
}
</style>
