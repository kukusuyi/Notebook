<template>
  <div class="page-shell">
    <header class="page-header">
      <div>
        <h2 class="page-title">AI 分析确认</h2>
        <p class="page-subtitle">
          这一页是正式入库前的最后一道人工确认。OCR 结果、标签和摘要都允许改，改完再保存。
        </p>
      </div>
      <div class="header-actions" v-if="draft">
        <el-button :loading="reanalyzing" @click="reanalyze">重新分析</el-button>
        <el-button @click="discardDraft">放弃本次结果</el-button>
        <el-button type="primary" :loading="saving" @click="saveDraft">保存正式错题</el-button>
      </div>
    </header>

    <el-empty
      v-if="!draft"
      description="当前没有待确认的 AI 草稿。你可以先去手动录入或上传图片。"
    />

    <div v-else class="review-grid">
      <section class="left-column">
        <ImagePreviewer :src="draft.source_image_url" />

        <AIModelSelector
          v-model:provider-name="providerName"
          v-model:model-name="modelName"
        />

        <div v-if="draft.ocr_context" class="paper-card ocr-card">
          <h3>OCR 提示</h3>
          <p class="meta-text">这部分只作为用户确认与 AI 分析上下文，不会写入正式错题主表。</p>
          <el-alert
            :title="`识别置信度：${draft.ocr_context.ocr_confidence}`"
            type="warning"
            :closable="false"
          />
          <div class="uncertain-list">
            <span
              v-for="item in draft.ocr_context.uncertain_parts"
              :key="item"
              class="tag-pill uncertain-pill"
            >
              {{ item }}
            </span>
            <span v-if="!draft.ocr_context.uncertain_parts.length" class="meta-text">
              当前没有 uncertain_parts。
            </span>
          </div>
        </div>
      </section>

      <QuestionForm
        :model="draft"
        :show-analysis-fields="true"
        :tag-options="tagStore.groupedOptions"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

import { analyzeWrongQuestion } from '@/api/ai.api'
import AIModelSelector from '@/components/AIModelSelector/index.vue'
import { createQuestion } from '@/api/question.api'
import ImagePreviewer from '@/components/ImagePreviewer/index.vue'
import QuestionForm from '@/components/QuestionForm/index.vue'
import { useDraftStore } from '@/stores/draft.store'
import { useTagStore } from '@/stores/tag.store'
import type { CreateWrongQuestionPayload } from '@/types/question'
import { getErrorMessage } from '@/utils/error'

const router = useRouter()
const draftStore = useDraftStore()
const tagStore = useTagStore()
const saving = ref(false)
const reanalyzing = ref(false)

const draft = computed(() => draftStore.currentDraft)
const providerName = computed({
  get: () => draft.value?.provider_name || '',
  set: (value: string) => {
    draftStore.updateAIModelSelection(value, draft.value?.model_name || '')
  },
})
const modelName = computed({
  get: () => draft.value?.model_name || '',
  set: (value: string) => {
    draftStore.updateAIModelSelection(draft.value?.provider_name || '', value)
  },
})

function discardDraft() {
  draftStore.resetDraft()
  router.push('/questions')
}

async function reanalyze() {
  if (!draft.value) {
    return
  }

  if (
    !draft.value.provider_name.trim() || !draft.value.model_name.trim()
  ) {
    ElMessage.warning('请先选择模型厂商和模型名称')
    return
  }

  reanalyzing.value = true
  try {
    const result = await analyzeWrongQuestion({
      provider_name: draft.value.provider_name,
      model_name: draft.value.model_name,
      chapter:
        draft.value.flow_mode === 'upload' && draft.value.chapter_locked
          ? (draft.value.chapter || undefined)
          : undefined,
      question_json: draft.value.question_json,
      ocr_context: draft.value.ocr_context,
    })
    draftStore.applyAnalysis(result)
    ElMessage.success('AI 分析结果已刷新')
  } catch (error) {
    ElMessage.error(getErrorMessage(error, '重新分析失败'))
  } finally {
    reanalyzing.value = false
  }
}

function toCreatePayload(): CreateWrongQuestionPayload | null {
  if (!draft.value) {
    return null
  }

  return {
    source_type: draft.value.source_type,
    source_image_id: draft.value.source_image_id,
    source_image_url: draft.value.source_image_url,
    subject: draft.value.subject,
    chapter: draft.value.chapter,
    question_json: draft.value.question_json,
    tags: draft.value.tags,
    semantic_summary: draft.value.semantic_summary,
    mistake_summary: draft.value.mistake_summary,
    difficulty_level: draft.value.difficulty_level,
    mastery_status: draft.value.mastery_status,
  }
}

async function saveDraft() {
  const payload = toCreatePayload()
  if (!payload) {
    return
  }

  if (!payload.question_json.question_core.trim()) {
    ElMessage.warning('question_core 不能为空')
    return
  }

  if (!payload.semantic_summary.trim()) {
    ElMessage.warning('semantic_summary 不能为空')
    return
  }

  saving.value = true

  try {
    const result = await createQuestion(payload)
    draftStore.resetDraft()
    ElMessage.success('错题保存成功')
    router.push(`/questions/${result.question_id}`)
  } catch (error) {
    ElMessage.error(getErrorMessage(error, '保存错题失败'))
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  try {
    await tagStore.fetchTags()
  } catch {
    // 标签选项加载失败不阻断确认页使用。
  }
})
</script>

<style scoped>
.header-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.review-grid {
  display: grid;
  grid-template-columns: 360px minmax(0, 1fr);
  gap: 20px;
}

.left-column {
  display: grid;
  gap: 16px;
  align-content: start;
}

.ocr-card {
  padding: 18px;
}

.ocr-card h3 {
  margin: 0;
}

.ocr-card p {
  margin: 8px 0 12px;
}

.uncertain-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 12px;
}

.uncertain-pill {
  background: rgba(192, 103, 44, 0.1);
  color: var(--accent);
  border-color: rgba(192, 103, 44, 0.16);
}

@media (max-width: 1080px) {
  .review-grid {
    grid-template-columns: 1fr;
  }
}
</style>
