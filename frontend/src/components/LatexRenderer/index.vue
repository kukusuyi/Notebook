<template>
  <div class="latex-renderer paper-panel">
    <div v-if="allowSourceToggle" class="renderer-toolbar">
      <el-radio-group v-model="viewMode" size="small">
        <el-radio-button label="preview">渲染预览</el-radio-button>
        <el-radio-button label="source">源码</el-radio-button>
      </el-radio-group>
      <el-button text size="small" @click="copySource">复制</el-button>
    </div>

    <div v-if="!content" class="renderer-empty">{{ emptyText }}</div>
    <pre v-else-if="viewMode === 'source'" class="renderer-source mono-text">{{ content }}</pre>
    <div
      v-else
      ref="contentRef"
      class="renderer-preview latex-content soft-scrollbar"
      :data-raw-content="content"
    ></div>
  </div>
</template>

<script setup lang="ts">
import renderMathInElement from 'katex/contrib/auto-render'
import { ElMessage } from 'element-plus'
import { computed, nextTick, onMounted, ref, watch } from 'vue'

import { latexDelimiters, normalizeLatexContent } from '@/utils/latex'

const props = withDefaults(
  defineProps<{
    content?: string
    emptyText?: string
    allowSourceToggle?: boolean
  }>(),
  {
    content: '',
    emptyText: '暂无内容',
    allowSourceToggle: false,
  },
)

const contentRef = ref<HTMLElement | null>(null)
const viewMode = ref<'preview' | 'source'>('preview')
const normalizedContent = computed(() => normalizeLatexContent(props.content))

async function renderContent() {
  if (!contentRef.value || viewMode.value !== 'preview') {
    return
  }

  const element = contentRef.value
  element.textContent = normalizedContent.value
  await nextTick()

  try {
    renderMathInElement(element, {
      delimiters: latexDelimiters,
      throwOnError: false,
      strict: 'ignore',
    })
  } catch {
    element.textContent = props.content
  }
}

async function copySource() {
  if (!props.content) {
    return
  }

  await navigator.clipboard.writeText(props.content)
  ElMessage.success('已复制源码')
}

watch([normalizedContent, viewMode], renderContent, { immediate: true, flush: 'post' })
onMounted(renderContent)
</script>

<style scoped>
.latex-renderer {
  overflow: hidden;
}

.renderer-toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border-bottom: 1px solid var(--line);
}

.renderer-empty,
.renderer-source,
.renderer-preview {
  min-height: 80px;
  margin: 0;
  padding: 16px;
}

.renderer-empty {
  display: grid;
  place-items: center;
  color: var(--text-secondary);
}

.renderer-source {
  overflow: auto;
  white-space: pre-wrap;
}

.renderer-preview {
  overflow: auto;
}
</style>
