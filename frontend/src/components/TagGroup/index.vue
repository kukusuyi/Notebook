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
])
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
  background: rgba(30, 77, 63, 0.1);
  border-color: rgba(30, 77, 63, 0.16);
  color: var(--primary);
}

.problem_type {
  background: rgba(192, 103, 44, 0.1);
  border-color: rgba(192, 103, 44, 0.16);
  color: var(--accent);
}

.method {
  background: rgba(37, 99, 235, 0.1);
  border-color: rgba(37, 99, 235, 0.16);
  color: #2356c7;
}

.mistake_reason {
  background: rgba(196, 61, 61, 0.1);
  border-color: rgba(196, 61, 61, 0.16);
  color: #b84141;
}
</style>
