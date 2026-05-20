<template>
    <div class="page-shell">
        <header class="page-header">
            <div>
                <h2 class="page-title">错题仪表盘</h2>
                <p class="page-subtitle">
                    这里汇总最近录入、掌握状态和高频错因，方便你从“收集”切到“复盘”。
                </p>
            </div>
            <div class="top-actions">
                <RouterLink to="/questions/create">
                    <el-button type="primary">手动录入</el-button>
                </RouterLink>
                <RouterLink to="/questions/upload">
                    <el-button plain>上传识别</el-button>
                </RouterLink>
                <RouterLink to="/questions">
                    <el-button plain>查看题库</el-button>
                </RouterLink>
            </div>
        </header>

        <section class="stats-grid">
            <article
                v-for="card in statsCards"
                :key="card.label"
                class="paper-card stat-card"
                :class="{ clickable: Boolean(card.onClick) }"
                @click="card.onClick?.()"
            >
                <div class="meta-row">
                    <span class="meta-text">{{ card.label }}</span>
                    <span v-if="card.badge" class="stat-badge">{{ card.badge }}</span>
                </div>
                <strong>{{ card.value }}</strong>
                <p>{{ card.description }}</p>
            </article>
        </section>

        <section class="insight-grid">
            <div class="paper-card section-card">
                <div class="section-title-row">
                    <div>
                        <h3>掌握状态分布</h3>
                        <p class="meta-text">点击任一状态可直达对应筛选列表。</p>
                    </div>
                </div>

                <div v-if="loading" class="loading-block">
                    <el-skeleton :rows="3" animated />
                </div>
                <div v-else class="distribution-list">
                    <button
                        v-for="item in summary.mastery_distribution"
                        :key="item.type"
                        class="distribution-item"
                        type="button"
                        @click="goMasteryFilter(item.type)"
                    >
                        <div class="distribution-head">
                            <span>{{ formatMasteryStatus(item.type) }}</span>
                            <strong>{{ item.count }}</strong>
                        </div>
                        <div class="distribution-track">
                            <span
                                class="distribution-fill mastery-fill"
                                :style="{ width: `${resolveDistributionWidth(summary.mastery_distribution, item.count)}%` }"
                            ></span>
                        </div>
                    </button>
                </div>
            </div>

            <div class="paper-card section-card">
                <div class="section-title-row">
                    <div>
                        <h3>来源分布</h3>
                        <p class="meta-text">快速定位图片题、手动录入题和导入题。</p>
                    </div>
                </div>

                <div v-if="loading" class="loading-block">
                    <el-skeleton :rows="3" animated />
                </div>
                <div v-else class="distribution-list">
                    <button
                        v-for="item in summary.source_distribution"
                        :key="item.type"
                        class="distribution-item"
                        type="button"
                        @click="goSourceFilter(item.type)"
                    >
                        <div class="distribution-head">
                            <span>{{ formatSourceType(item.type) }}</span>
                            <strong>{{ item.count }}</strong>
                        </div>
                        <div class="distribution-track accent-track">
                            <span
                                class="distribution-fill source-fill"
                                :style="{ width: `${resolveDistributionWidth(summary.source_distribution, item.count)}%` }"
                            ></span>
                        </div>
                    </button>
                </div>
            </div>

            <div class="paper-card section-card quick-card">
                <div class="section-title-row">
                    <div>
                        <h3>快捷入口</h3>
                        <p class="meta-text">把最常用的动作放在首页，减少来回切换。</p>
                    </div>
                </div>

                <div class="quick-actions">
                    <button class="quick-action primary-action" type="button" @click="goQuestionFilter({ mastery_status: 'unmastered' })">
                        <span>进入待掌握列表</span>
                        <small>优先处理还没吃透的题目</small>
                    </button>
                    <button class="quick-action" type="button" @click="router.push('/questions/upload')">
                        <span>继续上传识别</span>
                        <small>把纸面错题尽快沉淀进系统</small>
                    </button>
                    <button class="quick-action" type="button" @click="router.push('/tags')">
                        <span>整理标签体系</span>
                        <small>统一知识点与错因命名口径</small>
                    </button>
                </div>
            </div>
        </section>

        <section class="content-grid">
            <div class="paper-card section-card">
                <div class="section-title-row">
                    <div>
                        <h3>最近错题</h3>
                        <p class="meta-text">
                            最近录入的 4 道题会出现在这里，方便快速回到刚整理过的内容。
                        </p>
                    </div>
                    <RouterLink to="/questions">
                        <el-button text>查看全部</el-button>
                    </RouterLink>
                </div>

                <div v-if="loading" class="loading-block">
                    <el-skeleton :rows="4" animated />
                </div>
                <div v-else-if="recentQuestions.length" class="recent-list">
                    <QuestionCard
                        v-for="item in recentQuestions"
                        :key="item.question_id"
                        :item="item"
                    />
                </div>
                <el-empty
                    v-else
                    description="还没有错题数据，先去录入第一道题吧。"
                />
            </div>

            <div class="paper-card section-card">
                <div class="section-title-row">
                    <div>
                        <h3>标签热点</h3>
                        <p class="meta-text">按知识点和错因拆分，便于识别“考点密度”和“失误模式”。</p>
                    </div>
                    <RouterLink to="/tags">
                        <el-button text>管理标签</el-button>
                    </RouterLink>
                </div>

                <div v-if="loading" class="loading-block">
                    <el-skeleton :rows="6" animated />
                </div>
                <div v-else class="tag-rank-grid">
                    <section class="tag-rank-panel">
                        <div class="rank-title">高频知识点</div>
                        <div v-if="tagGroups.knowledge_points.length" class="tag-list">
                            <button
                                v-for="tag in tagGroups.knowledge_points"
                                :key="tag.tag_id"
                                class="tag-rank-item"
                                type="button"
                                @click="goTag(tag.tag_name, tag.tag_type)"
                            >
                                <span>{{ truncateText(tag.tag_name, 16) }}</span>
                                <strong>{{ tag.usage_count }}</strong>
                            </button>
                        </div>
                        <el-empty v-else description="暂无知识点标签" :image-size="72" />
                    </section>

                    <section class="tag-rank-panel">
                        <div class="rank-title">高频错因</div>
                        <div v-if="tagGroups.mistake_reasons.length" class="tag-list">
                            <button
                                v-for="tag in tagGroups.mistake_reasons"
                                :key="tag.tag_id"
                                class="tag-rank-item danger-item"
                                type="button"
                                @click="goTag(tag.tag_name, tag.tag_type)"
                            >
                                <span>{{ truncateText(tag.tag_name, 16) }}</span>
                                <strong>{{ tag.usage_count }}</strong>
                            </button>
                        </div>
                        <el-empty v-else description="暂无错因标签" :image-size="72" />
                    </section>
                </div>
            </div>
        </section>
    </div>
</template>

<script setup lang="ts">
import { ElMessage } from "element-plus";
import { computed, onMounted, ref } from "vue";
import { RouterLink, useRouter } from "vue-router";

import QuestionCard from "@/components/QuestionCard/index.vue";
import {
    getDashboardRecentQuestions,
    getDashboardSummary,
    getDashboardTopTags,
} from "@/api/dashboard.api";
import type {
    DashboardDistributionItem,
    DashboardSummaryResponse,
    DashboardTagsResponse,
} from "@/types/dashboard";
import type { MasteryStatus, SourceType } from "@/types/common";
import type { QuestionListItem } from "@/types/question";
import type { TagType } from "@/types/tag";
import { getErrorMessage } from "@/utils/error";
import {
    formatMasteryStatus,
    formatSourceType,
    truncateText,
} from "@/utils/format";

const router = useRouter();
const loading = ref(false);
const summary = ref<DashboardSummaryResponse>({
    total_questions: 0,
    today_added: 0,
    unmastered_count: 0,
    image_bound_count: 0,
    active_tag_count: 0,
    mastery_distribution: [],
    source_distribution: [],
});
const recentQuestions = ref<QuestionListItem[]>([]);
const tagGroups = ref<DashboardTagsResponse>({
    knowledge_points: [],
    mistake_reasons: [],
});

const statsCards = computed(() => [
    {
        label: "错题总数",
        value: summary.value.total_questions,
        description: "当前库内已沉淀的正式错题数量。",
        badge: "总览",
        onClick: () => router.push("/questions"),
    },
    {
        label: "今日新增",
        value: summary.value.today_added,
        description: "按服务端当天创建时间实时汇总。",
        badge: "Today",
    },
    {
        label: "待掌握",
        value: summary.value.unmastered_count,
        description: "建议优先从这里进入复盘节奏。",
        badge: "Focus",
        onClick: () => goQuestionFilter({ mastery_status: "unmastered" }),
    },
    {
        label: "已绑定图片",
        value: summary.value.image_bound_count,
        description: "保留了原图上下文，适合回看纸面信息。",
        badge: "Image",
        onClick: () => goQuestionFilter({ source_type: "image" }),
    },
    {
        label: "活跃标签",
        value: summary.value.active_tag_count,
        description: "当前启用中的标签定义总数。",
        badge: "Tags",
        onClick: () => router.push("/tags"),
    },
]);

function goQuestionFilter(query: {
    mastery_status?: MasteryStatus;
    source_type?: SourceType;
}) {
    router.push({
        path: "/questions",
        query,
    });
}

function goMasteryFilter(value: string) {
    goQuestionFilter({ mastery_status: value as MasteryStatus });
}

function goSourceFilter(value: string) {
    goQuestionFilter({ source_type: value as SourceType });
}

function goTag(name: string, type: TagType) {
    router.push({
        path: "/questions",
        query: {
            tagName: name,
            tagType: type,
        },
    });
}

function resolveDistributionWidth(
    items: DashboardDistributionItem[],
    count: number,
) {
    const max = Math.max(...items.map((item) => item.count), 0);
    if (max <= 0 || count <= 0) {
        return 0;
    }
    return Math.max(Math.round((count / max) * 100), 14);
}

async function loadData() {
    loading.value = true;
    try {
        const [summaryResponse, recentResponse, tagResponse] = await Promise.all([
            getDashboardSummary(),
            getDashboardRecentQuestions(4),
            getDashboardTopTags(6),
        ]);

        summary.value = summaryResponse;
        recentQuestions.value = recentResponse.list;
        tagGroups.value = tagResponse;
    } catch (error) {
        ElMessage.error(getErrorMessage(error, "仪表盘数据加载失败"));
    } finally {
        loading.value = false;
    }
}

onMounted(loadData);
</script>

<style scoped>
.top-actions {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
}

.stats-grid {
    display: grid;
    grid-template-columns: repeat(5, minmax(0, 1fr));
    gap: 16px;
}

.stat-card {
    padding: 18px;
    transition:
        transform 0.18s ease,
        box-shadow 0.18s ease,
        border-color 0.18s ease;
}

.stat-card.clickable {
    cursor: pointer;
}

.stat-card.clickable:hover {
    transform: translateY(-2px);
    border-color: rgba(30, 77, 63, 0.18);
}

.meta-row {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    align-items: center;
}

.stat-badge {
    display: inline-flex;
    align-items: center;
    min-height: 24px;
    padding: 0 10px;
    border-radius: 999px;
    background: rgba(30, 77, 63, 0.08);
    color: var(--primary);
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.04em;
    text-transform: uppercase;
}

.stat-card strong {
    display: block;
    margin-top: 12px;
    font-size: 38px;
    line-height: 1;
    color: var(--primary);
}

.stat-card p {
    margin: 12px 0 0;
    color: var(--text-secondary);
}

.insight-grid {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) minmax(280px, 0.8fr);
    gap: 20px;
}

.content-grid {
    display: grid;
    grid-template-columns: minmax(0, 1.1fr) minmax(320px, 0.9fr);
    gap: 20px;
}

.section-card {
    padding: 20px;
}

.section-title-row {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    align-items: flex-start;
    margin-bottom: 16px;
}

.section-title-row h3 {
    margin: 0;
}

.distribution-list,
.recent-list,
.quick-actions,
.tag-list {
    display: grid;
    gap: 12px;
}

.distribution-item,
.quick-action,
.tag-rank-item {
    width: 100%;
    padding: 0;
    border: 0;
    background: transparent;
    color: inherit;
    font: inherit;
    text-align: left;
}

.distribution-item {
    display: grid;
    gap: 10px;
    padding: 14px 16px;
    border-radius: 16px;
    border: 1px solid var(--line);
    background: rgba(255, 255, 255, 0.38);
    cursor: pointer;
    transition:
        transform 0.18s ease,
        border-color 0.18s ease,
        background-color 0.18s ease;
}

.distribution-item:hover,
.quick-action:hover,
.tag-rank-item:hover {
    transform: translateY(-1px);
    border-color: rgba(30, 77, 63, 0.18);
}

.distribution-head {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    align-items: center;
}

.distribution-track {
    overflow: hidden;
    height: 10px;
    border-radius: 999px;
    background: rgba(30, 77, 63, 0.08);
}

.accent-track {
    background: rgba(192, 103, 44, 0.12);
}

.distribution-fill {
    display: block;
    height: 100%;
    border-radius: inherit;
}

.mastery-fill {
    background: linear-gradient(90deg, #1e4d3f, #3d7d6b);
}

.source-fill {
    background: linear-gradient(90deg, #c0672c, #d4934c);
}

.quick-card {
    background:
        radial-gradient(circle at top right, rgba(192, 103, 44, 0.14), transparent 45%),
        var(--paper-bg);
}

.quick-action {
    display: grid;
    gap: 4px;
    padding: 16px;
    border-radius: 18px;
    border: 1px solid var(--line);
    background: rgba(255, 255, 255, 0.5);
    cursor: pointer;
    transition:
        transform 0.18s ease,
        border-color 0.18s ease,
        background-color 0.18s ease;
}

.quick-action span {
    font-weight: 700;
}

.quick-action small {
    color: var(--text-secondary);
}

.primary-action {
    border-color: rgba(30, 77, 63, 0.22);
    background: rgba(30, 77, 63, 0.08);
}

.tag-rank-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
}

.tag-rank-panel {
    display: grid;
    gap: 12px;
}

.rank-title {
    font-weight: 700;
}

.tag-rank-item {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    align-items: center;
    padding: 12px 14px;
    border-radius: 14px;
    border: 1px solid rgba(30, 77, 63, 0.12);
    background: rgba(30, 77, 63, 0.05);
    cursor: pointer;
    transition:
        transform 0.18s ease,
        border-color 0.18s ease;
}

.danger-item {
    border-color: rgba(192, 103, 44, 0.14);
    background: rgba(192, 103, 44, 0.08);
}

@media (max-width: 1280px) {
    .stats-grid {
        grid-template-columns: repeat(3, minmax(0, 1fr));
    }

    .insight-grid {
        grid-template-columns: 1fr 1fr;
    }

    .content-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 900px) {
    .stats-grid,
    .insight-grid,
    .tag-rank-grid {
        grid-template-columns: 1fr;
    }
}
</style>
