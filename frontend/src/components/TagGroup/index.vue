<template>
  <div class="tag-group">
    <section v-for="group in displayGroups" :key="group.key" class="tag-section">
      <div class="tag-label">{{ group.label }}</div>
      <div class="tag-list">
        <span v-if="group.items.length === 0" class="meta-text">暂无标签</span>
        <button
          v-for="item in group.items"
          :key="`${group.key}-${item}`"
          type="button"
          class="tag-pill tag-button"
          :class="group.key"
          @click="$emit('tag-click', { type: group.key, name: item })"
        >
          {{ item }}
        </button>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

import type { TagGroups } from '@/types/question'

const props = defineProps<{
  tags: TagGroups
}>()

defineEmits<{
  (event: 'tag-click', payload: { type: keyof TagGroups; name: string }): void
}>()

const displayGroups = computed(() => [
  { key: 'knowledge_points' as const, label: '知识点', items: props.tags.knowledge_points },
  { key: 'problem_type' as const, label: '题型', items: props.tags.problem_type },
  { key: 'method' as const, label: '解法', items: props.tags.method },
  { key: 'mistake_reason' as const, label: '错因', items: props.tags.mistake_reason },
].filter(group=>group.items.length))
</script>

<style scoped>
.tag-group {
  display: grid;
  gap: 12px;
}

.tag-section {
  display: grid;
  gap: 8px;
}

.tag-label {
  font-size: 12px;
  font-weight: 700;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.tag-button {
  cursor: pointer;
  background: transparent;
}

.knowledge_points {
  background: var(--primary-soft);
  border-color: var(--primary-soft);
  color: var(--primary);
}

.problem_type {
  background: var(--primary-soft);
  border-color: var(--primary-soft);
  color: var(--accent);
}

.method {
  background: var(--primary-soft);
  border-color: var(--primary-soft);
  color: var(--primary);
}

.mistake_reason {
  background: var(--danger-soft);
  border-color: var(--danger-soft);
  color: var(--el-color-danger);
}
</style>
