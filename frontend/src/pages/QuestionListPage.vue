<template>
    <div class="page-shell">
        <header class="page-header">
            <div>
                <h2 class="page-title">错题列表</h2>
                <p class="page-subtitle">
                    当前优先支持关键词、学科、掌握状态、来源类型和标签筛选。
                </p>
            </div>
            <div class="header-actions">
                <el-radio-group
                    :model-value="questionStore.preferredListView"
                    @update:model-value="questionStore.setPreferredListView"
                >
                    <el-radio-button label="card">卡片视图</el-radio-button>
                    <el-radio-button label="table">表格视图</el-radio-button>
                </el-radio-group>
            </div>
        </header>

        <section class="paper-card filter-card">
            <el-form label-position="top">
                <div class="filter-grid">
                    <el-form-item label="关键词">
                        <el-input
                            v-model="filters.keyword"
                            placeholder="搜索题目主干、标签等关键信息"
                        />
                    </el-form-item>
                    <el-form-item label="学科">
                        <el-input
                            v-model="filters.subject"
                            placeholder="例如 math / 高等数学"
                        />
                    </el-form-item>
                    <el-form-item label="掌握状态">
                        <el-select v-model="filters.mastery_status" clearable>
                            <el-option label="未掌握" value="unmastered" />
                            <el-option label="学习中" value="learning" />
                            <el-option label="已掌握" value="mastered" />
                        </el-select>
                    </el-form-item>
                    <el-form-item label="来源类型">
                        <el-select v-model="filters.source_type" clearable>
                            <el-option label="手动录入" value="manual" />
                            <el-option label="图片识别" value="image" />
                            <el-option label="导入" value="import" />
                        </el-select>
                    </el-form-item>
                </div>

                <div class="filter-actions">
                    <span v-if="activeTagHint" class="meta-text">
                        当前通过标签筛选：{{ activeTagHint }}
                    </span>
                    <div class="grow"></div>
                    <el-button @click="resetFilters">重置</el-button>
                    <el-button type="primary" @click="loadQuestions"
                        >查询</el-button
                    >
                </div>
            </el-form>
        </section>

        <section class="paper-card list-card">
            <div class="list-toolbar">
                <div class="toolbar-left">
                    <div class="meta-text">共 {{ total }} 条错题</div>
                    <div v-if="selectedQuestionIds.length" class="selection-summary">
                        <span class="meta-text">已选 {{ selectedQuestionIds.length }} 题</span>
                        <el-button text @click="clearSelection">清空已选</el-button>
                    </div>
                </div>
                <div class="toolbar-actions">
                    <el-dropdown
                        trigger="click"
                        @command="handleExportCommand"
                    >
                        <el-button
                            type="primary"
                            plain
                            :disabled="!selectedQuestionIds.length"
                        >
                            导出 PDF
                        </el-button>
                        <template #dropdown>
                            <el-dropdown-menu>
                                <el-dropdown-item command="with_answers">
                                    携带答案导出
                                </el-dropdown-item>
                                <el-dropdown-item command="questions_only">
                                    仅导出题目
                                </el-dropdown-item>
                            </el-dropdown-menu>
                        </template>
                    </el-dropdown>
                    <RouterLink to="/questions/create">
                        <el-button text>新增错题</el-button>
                    </RouterLink>
                </div>
            </div>

            <div v-if="loading" class="loading-block">
                <el-skeleton :rows="6" animated />
            </div>

            <template v-else>
                <div
                    v-if="questionStore.preferredListView === 'card'"
                    class="card-grid"
                >
                    <QuestionCard
                        v-for="item in list"
                        :key="item.question_id"
                        :item="item"
                        :selected="isQuestionSelected(item.question_id)"
                        @toggle-select="toggleSelection(item.question_id)"
                    />
                </div>

                <el-table v-else :data="list" class="question-table">
                    <el-table-column label="选择" width="78">
                        <template #default="{ row }">
                            <el-checkbox
                                :model-value="isQuestionSelected(row.question_id)"
                                @change="toggleSelection(row.question_id)"
                            />
                        </template>
                    </el-table-column>
                    <el-table-column prop="question_id" label="ID" width="88" />
                    <el-table-column label="题目">
                        <template #default="{ row }">
                            {{ truncateText(row.question_core, 72) }}
                        </template>
                    </el-table-column>
                    <el-table-column prop="subject" label="学科" width="120" />
                    <el-table-column label="掌握状态" width="120">
                        <template #default="{ row }">
                            {{ formatMasteryStatus(row.mastery_status) }}
                        </template>
                    </el-table-column>
                    <el-table-column
                        prop="created_at"
                        label="创建时间"
                        width="180"
                    >
                        <template #default="{ row }">
                            {{ formatDateTime(row.created_at) }}
                        </template>
                    </el-table-column>
                    <el-table-column label="操作" width="180">
                        <template #default="{ row }">
                            <RouterLink :to="`/questions/${row.question_id}`">
                                <el-button text>详情</el-button>
                            </RouterLink>
                            <RouterLink
                                :to="`/questions/${row.question_id}/edit`"
                            >
                                <el-button text>编辑</el-button>
                            </RouterLink>
                        </template>
                    </el-table-column>
                </el-table>

                <el-empty
                    v-if="!list.length"
                    description="暂无符合条件的错题"
                />

                <div class="pagination-row">
                    <el-pagination
                        background
                        layout="prev, pager, next"
                        :total="total"
                        :page-size="filters.page_size"
                        :current-page="filters.page"
                        @current-change="handlePageChange"
                    />
                </div>
            </template>
        </section>
    </div>
</template>

<script setup lang="ts">
import { ElMessage } from "element-plus";
import { computed, onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";

import QuestionCard from "@/components/QuestionCard/index.vue";
import {
    buildQuestionExportPrintURL,
    type QuestionExportMode,
    listQuestions,
} from "@/api/question.api";
import { listTags } from "@/api/tag.api";
import { useQuestionStore } from "@/stores/question.store";
import type { MasteryStatus, SourceType } from "@/types/common";
import type { ListQuestionFilter, QuestionListItem } from "@/types/question";
import { getErrorMessage } from "@/utils/error";
import {
    formatDateTime,
    formatMasteryStatus,
    truncateText,
} from "@/utils/format";

const route = useRoute();
const router = useRouter();
const questionStore = useQuestionStore();
const loading = ref(false);
const total = ref(0);
const list = ref<QuestionListItem[]>([]);
const activeTagHint = ref("");
const selectedQuestionIds = ref<number[]>([]);
const allowedMasteryStatus: MasteryStatus[] = ["unmastered", "learning", "mastered"];
const allowedSourceType: SourceType[] = ["manual", "image", "import"];

const filters = reactive<
    Required<Pick<ListQuestionFilter, "page" | "page_size">> & {
        keyword: string;
        subject: string;
        chapter: string;
        mastery_status: MasteryStatus | "";
        source_type: SourceType | "";
        tag_ids: string;
    }
>({
    page: 1,
    page_size: 10,
    keyword: "",
    subject: "",
    chapter: "",
    mastery_status: "",
    source_type: "",
    tag_ids: "",
});

const routeTagName = computed(() => {
    const value = route.query.tagName;
    return typeof value === "string" ? value : "";
});

const routeTagType = computed(() => {
    const value = route.query.tagType;
    return typeof value === "string" ? value : "";
});

function normalizeMasteryStatus(value: unknown): MasteryStatus | "" {
    return typeof value === "string" && allowedMasteryStatus.includes(value as MasteryStatus)
        ? (value as MasteryStatus)
        : "";
}

function normalizeSourceType(value: unknown): SourceType | "" {
    return typeof value === "string" && allowedSourceType.includes(value as SourceType)
        ? (value as SourceType)
        : "";
}

function syncFiltersFromRoute() {
    filters.keyword =
        typeof route.query.keyword === "string" ? route.query.keyword : "";
    filters.subject =
        typeof route.query.subject === "string" ? route.query.subject : "";
    filters.chapter =
        typeof route.query.chapter === "string" ? route.query.chapter : "";
    filters.mastery_status = normalizeMasteryStatus(route.query.mastery_status);
    filters.source_type = normalizeSourceType(route.query.source_type);
}

async function syncTagFilterFromRoute() {
    if (!routeTagName.value) {
        filters.tag_ids = "";
        activeTagHint.value = "";
        return;
    }

    const tagTypeMap: Record<string, string> = {
        knowledge_points: "knowledge_point",
        knowledge_point: "knowledge_point",
        problem_type: "problem_type",
        method: "method",
        mistake_reason: "mistake_reason",
    };

    const response = await listTags({
        keyword: routeTagName.value,
        tag_type: tagTypeMap[routeTagType.value] || "",
    });

    const matched = response.list.find(
        (item) => item.tag_name === routeTagName.value,
    );
    filters.tag_ids = matched ? String(matched.tag_id) : "";
    activeTagHint.value = matched
        ? `${routeTagName.value} (${matched.tag_type})`
        : `${routeTagName.value} (未匹配到 tag_id，已退化为普通列表查询)`;
}

async function loadQuestions() {
    loading.value = true;

    try {
        await syncTagFilterFromRoute();
        const response = await listQuestions({
            ...filters,
            mastery_status: filters.mastery_status || undefined,
            source_type: filters.source_type || undefined,
            tag_ids: filters.tag_ids || undefined,
            chapter: filters.chapter || undefined,
        });

        list.value = response.list;
        total.value = response.total;
        questionStore.setRecentQuestions(response.list.slice(0, 4));
    } catch (error) {
        ElMessage.error(getErrorMessage(error, "错题列表加载失败"));
    } finally {
        loading.value = false;
    }
}

function isQuestionSelected(questionID: number) {
    return selectedQuestionIds.value.includes(questionID);
}

function toggleSelection(questionID: number) {
    if (isQuestionSelected(questionID)) {
        selectedQuestionIds.value = selectedQuestionIds.value.filter((item) => item !== questionID);
        return;
    }

    selectedQuestionIds.value = [...selectedQuestionIds.value, questionID];
}

function clearSelection() {
    selectedQuestionIds.value = [];
}

function exportSelectedQuestions(exportMode: QuestionExportMode) {
    if (!selectedQuestionIds.value.length) {
        ElMessage.warning("请先选择要导出的错题");
        return;
    }

    const exportURL = buildQuestionExportPrintURL(selectedQuestionIds.value, exportMode);
    window.open(exportURL, "_blank", "noopener,noreferrer");
}

function handleExportCommand(command: string) {
    if (command !== "with_answers" && command !== "questions_only") {
        ElMessage.error("导出模式不支持");
        return;
    }

    exportSelectedQuestions(command);
}

async function resetFilters() {
    filters.page = 1;
    filters.keyword = "";
    filters.subject = "";
    filters.chapter = "";
    filters.mastery_status = "";
    filters.source_type = "";
    filters.tag_ids = "";
    activeTagHint.value = "";

    if (Object.keys(route.query).length) {
        await router.push({ path: "/questions", query: {} });
        return;
    }

    loadQuestions();
}

function handlePageChange(page: number) {
    filters.page = page;
    loadQuestions();
}

onMounted(() => {
    syncFiltersFromRoute();
    loadQuestions();
});

watch(
    () => route.query,
    () => {
        filters.page = 1;
        syncFiltersFromRoute();
        loadQuestions();
    },
);
</script>

<style scoped>
.header-actions {
    display: flex;
    gap: 12px;
}

.filter-card,
.list-card {
    padding: 20px;
}

.filter-grid {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 16px;
}

.filter-actions,
.list-toolbar,
.pagination-row {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
}

.filter-actions {
    margin-top: 8px;
}

.grow {
    flex: 1;
}

.list-toolbar {
    justify-content: space-between;
    margin-bottom: 16px;
}

.toolbar-left,
.toolbar-actions,
.selection-summary {
    display: flex;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
}

.card-grid {
    display: grid;
    gap: 16px;
}

.pagination-row {
    justify-content: flex-end;
    margin-top: 18px;
}

@media (max-width: 1100px) {
    .filter-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
    }
}

@media (max-width: 720px) {
    .filter-grid {
        grid-template-columns: 1fr;
    }
}
</style>
