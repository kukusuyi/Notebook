<template>
  <div class="json-editor paper-panel">
    <div class="editor-toolbar">
      <div class="meta-text">标准错题 JSON 编辑器</div>
      <div class="toolbar-actions">
        <el-button text size="small" @click="formatValue">格式化</el-button>
        <el-button text size="small" @click="emitCurrent">同步到表单</el-button>
      </div>
    </div>

    <el-input
      v-model="rawValue"
      type="textarea"
      :autosize="{ minRows: 14, maxRows: 24 }"
      class="mono-text"
      @blur="emitCurrent"
    />

    <div class="editor-footer">
      <span :class="hasError ? 'error-text' : 'meta-text'">
        {{ message }}
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'

import type { QuestionJSON } from '@/types/question'
import { formatQuestionJSON, parseQuestionJSON } from '@/utils/json'

const props = defineProps<{
  modelValue: QuestionJSON
}>()

const emit = defineEmits<{
  (event: 'update:modelValue', value: QuestionJSON): void
  (event: 'validation-change', value: boolean): void
}>()

const rawValue = ref(formatQuestionJSON(props.modelValue))
const message = ref('支持直接粘贴 question_core / standard_solution / wrong_solution。')
const hasError = ref(false)

watch(
  () => props.modelValue,
  (value) => {
    rawValue.value = formatQuestionJSON(value)
  },
  { deep: true },
)

function emitCurrent() {
  try {
    const parsed = parseQuestionJSON(rawValue.value)
    emit('update:modelValue', parsed)
    emit('validation-change', true)
    hasError.value = false
    message.value = 'JSON 格式正确。'
  } catch (error) {
    emit('validation-change', false)
    hasError.value = true
    message.value = error instanceof Error ? error.message : 'JSON 格式错误。'
  }
}

function formatValue() {
  emitCurrent()
  if (!hasError.value) {
    rawValue.value = formatQuestionJSON(parseQuestionJSON(rawValue.value))
  }
}
</script>

<style scoped>
.json-editor {
  overflow: hidden;
}

.editor-toolbar,
.editor-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 16px;
}

.editor-toolbar {
  border-bottom: 1px solid var(--line);
}

.toolbar-actions {
  display: flex;
  gap: 4px;
}

.editor-footer {
  border-top: 1px solid var(--line);
}

.error-text {
  color: #b84141;
  font-size: 13px;
}
</style>
