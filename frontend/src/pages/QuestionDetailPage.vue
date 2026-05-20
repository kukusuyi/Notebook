<template>
  <div class="page-shell" v-loading="loading">
    <header class="page-header">
      <div>
        <h2 class="page-title">错题详情</h2>
        <p class="page-subtitle">
          详情页集中展示题目、原图、标准解法、错误思路、标签和相似题入口，是复盘的核心页面。
        </p>
      </div>
      <div v-if="detail" class="header-actions">
        <RouterLink :to="`/questions/${detail.question_id}/edit`">
          <el-button>编辑</el-button>
        </RouterLink>
        <RouterLink :to="`/questions/${detail.question_id}/similar`">
          <el-button type="primary" plain>查找相似题</el-button>
        </RouterLink>
        <el-button type="danger" plain @click="removeQuestion">删除</el-button>
      </div>
    </header>

    <el-empty v-if="!loading && !detail" description="未找到这道错题" />

    <template v-else-if="detail">
      <section class="summary-grid">
        <article class="paper-card summary-card">
          <div class="meta-text">题目元信息</div>
          <el-descriptions :column="2" border>
            <el-descriptions-item label="ID">{{ detail.question_id }}</el-descriptions-item>
            <el-descriptions-item label="学科">{{ detail.subject }}</el-descriptions-item>
            <el-descriptions-item label="章节">{{ detail.chapter || '--' }}</el-descriptions-item>
            <el-descriptions-item label="来源">{{ detail.source_type }}</el-descriptions-item>
            <el-descriptions-item label="掌握状态">{{ formatMasteryStatus(detail.mastery_status) }}</el-descriptions-item>
            <el-descriptions-item label="难度">{{ detail.difficulty_level }}</el-descriptions-item>
            <el-descriptions-item label="创建时间">
              {{ formatDateTime(detail.created_at) }}
            </el-descriptions-item>
            <el-descriptions-item label="更新时间">
              {{ formatDateTime(detail.updated_at) }}
            </el-descriptions-item>
          </el-descriptions>
        </article>

        <ImagePreviewer :src="detail.source_image_url" />
      </section>

      <section class="paper-card section-card">
        <div class="section-title">题目主干</div>
        <LatexRenderer :content="detail.question_core" allow-source-toggle />
      </section>

      <section class="content-split">
        <div class="paper-card section-card">
          <div class="section-title">标准解法</div>
          <LatexRenderer :content="detail.standard_solution" allow-source-toggle />
        </div>

        <div class="paper-card section-card">
          <div class="section-title">错误解法 / 错误思路</div>
          <LatexRenderer :content="detail.wrong_solution" allow-source-toggle />
        </div>
      </section>

      <section class="content-split">
        <div class="paper-card section-card">
          <div class="section-title">语义摘要</div>
          <div class="summary-text">{{ detail.semantic_summary || '暂无语义摘要' }}</div>
        </div>

        <div class="paper-card section-card">
          <div class="section-title">错因摘要</div>
          <div class="summary-text">{{ detail.mistake_summary || '暂无错因摘要' }}</div>
        </div>
      </section>

      <section class="paper-card section-card">
        <div class="section-title">标签分组</div>
        <TagGroup :tags="detail.tags" @tag-click="handleTagClick" />
      </section>

      <section class="paper-card section-card">
        <div class="section-title-row">
          <div class="section-title">相似题预览</div>
          <RouterLink :to="`/questions/${detail.question_id}/similar`">
            <el-button text>查看完整列表</el-button>
          </RouterLink>
        </div>
        <div class="similar-list">
          <SimilarQuestionCard
            v-for="item in similarList"
            :key="item.question_id"
            :item="item"
          />
          <el-empty v-if="!similarList.length" description="暂未找到相似题" />
        </div>
      </section>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from 'element-plus'
import { ref, watch } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'

import ImagePreviewer from '@/components/ImagePreviewer/index.vue'
import LatexRenderer from '@/components/LatexRenderer/index.vue'
import SimilarQuestionCard from '@/components/SimilarQuestionCard/index.vue'
import TagGroup from '@/components/TagGroup/index.vue'
import { deleteQuestion, findSimilarQuestions, getQuestionDetail } from '@/api/question.api'
import type { QuestionDetail, SimilarQuestionItem } from '@/types/question'
import { getErrorMessage } from '@/utils/error'
import { formatDateTime, formatMasteryStatus } from '@/utils/format'

const route = useRoute()
const router = useRouter()
const loading = ref(false)
const detail = ref<QuestionDetail | null>(null)
const similarList = ref<SimilarQuestionItem[]>([])

function getQuestionID() {
  return Number(route.params.id)
}

function handleTagClick(payload: { type: string; name: string }) {
  router.push({
    path: '/questions',
    query: {
      tagName: payload.name,
      tagType: payload.type,
    },
  })
}

async function loadDetail() {
  detail.value = null
  similarList.value = []
  loading.value = true
  try {
    detail.value = await getQuestionDetail(getQuestionID())
    const similarResponse = await findSimilarQuestions(getQuestionID(), {
      vector_type: 'semantic',
      limit: 3,
      use_tag_filter: false,
    })
    similarList.value = similarResponse.list
  } catch (error) {
    ElMessage.error(getErrorMessage(error, '错题详情加载失败'))
  } finally {
    loading.value = false
  }
}

async function removeQuestion() {
  const current = detail.value
  if (!current) {
    return
  }

  try {
    await ElMessageBox.confirm(
      '删除后该错题将无法在列表中查看，关联向量也会被删除。是否继续？',
      '确认删除',
      { type: 'warning' },
    )

    await deleteQuestion(current.question_id)
    ElMessage.success('错题已删除')
    router.push('/questions')
  } catch (error) {
    if (error instanceof Error && error.message !== 'cancel') {
      ElMessage.error(getErrorMessage(error, '删除失败'))
    }
  }
}

watch(
  () => route.params.id,
  () => {
    void loadDetail()
  },
  { immediate: true },
)
</script>

<style scoped>
.header-actions {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.summary-grid,
.content-split {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  gap: 20px;
}

.summary-card,
.section-card {
  padding: 20px;
}

.section-title,
.section-title-row {
  margin-bottom: 14px;
  font-size: 20px;
  font-weight: 700;
}

.section-title-row {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: center;
}

.summary-text {
  min-height: 120px;
  line-height: 1.8;
  white-space: pre-wrap;
  color: var(--text-main);
}

.similar-list {
  display: grid;
  gap: 14px;
}

@media (max-width: 1080px) {
  .summary-grid,
  .content-split {
    grid-template-columns: 1fr;
  }
}
</style>
