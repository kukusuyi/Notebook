<template>
    <div class="page-shell">
        <header class="page-header">
            <div>
                <h2 class="page-title">图片上传与 OCR 识别</h2>
                <p class="page-subtitle">
                    这个流程现在遵循“上传图片 → OCR → OCR 结果确认 → AI 分析 →
                    用户确认 → 保存正式错题”。
                </p>
            </div>
        </header>

        <section class="paper-card step-card">
            <el-steps :active="activeStep" finish-status="success">
                <el-step title="上传图片" />
                <el-step title="OCR 识别" />
                <el-step title="OCR 确认" />
                <el-step title="AI 分析" />
                <el-step title="确认保存" />
            </el-steps>
        </section>

        <div class="upload-layout">
            <div class="left-column">
                <UploadPanel
                    :uploaded-image="
                        draft
                            ? {
                                  image_id: draft.source_image_id,
                                  image_url: draft.source_image_url,
                              }
                            : undefined
                    "
                    @success="handleUploadSuccess"
                />
            </div>

            <div class="right-column">
                <div class="paper-card status-panel">
                    <h3>当前状态</h3>
                    <p class="meta-text">
                        上传不会自动创建错题。只有在 AI
                        分析确认页点击保存后，才会真正写入数据库。
                    </p>

                    <el-descriptions :column="1" border>
                        <el-descriptions-item label="图片 ID">
                            {{ draft?.source_image_id || "--" }}
                        </el-descriptions-item>
                        <el-descriptions-item label="图片 URL">
                            <span class="mono-text url-text">{{
                                draft?.source_image_url || "--"
                            }}</span>
                        </el-descriptions-item>
                        <el-descriptions-item label="草稿状态">
                            {{ draft?.status || "draft" }}
                        </el-descriptions-item>
                    </el-descriptions>

                    <div class="status-actions">
                        <el-button
                            type="primary"
                            class="status-action-button"
                            :disabled="!draft?.source_image_id"
                            :loading="processing"
                            @click="runOCR"
                        >
                            {{
                                hasOCRResult ? "重新 OCR 识别" : "开始 OCR 识别"
                            }}
                        </el-button>
                        <el-button
                            v-if="draft?.status === 'ocr_reviewing'"
                            type="success"
                            class="status-action-button"
                            :loading="processing"
                            @click="runAnalysis"
                        >
                            确认 OCR 结果并继续 AI 分析
                        </el-button>
                        <el-button
                            v-if="draft?.status === 'ai_reviewing'"
                            type="success"
                            class="status-action-button"
                            @click="router.push('/questions/ai-review')"
                        >
                            前往最终确认页
                        </el-button>
                        <el-button
                            class="status-action-button secondary-action"
                            @click="resetUploadDraft"
                        >
                            重新开始
                        </el-button>
                    </div>

                    <div v-if="draft?.ocr_context" class="ocr-tip">
                        <div class="meta-text">OCR 识别结果预告</div>
                        <div>
                            置信度：{{ draft.ocr_context.ocr_confidence }}
                        </div>
                        <div>
                            不确定片段：
                            {{
                                draft.ocr_context.uncertain_parts.length
                                    ? draft.ocr_context.uncertain_parts.join(
                                          " / ",
                                      )
                                    : "无"
                            }}
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <section
            v-if="draft && draft.status === 'ocr_reviewing'"
            class="ocr-review-section"
        >
            <div class="paper-card review-intro">
                <h3>OCR 结果确认</h3>
                <p class="meta-text">
                    先检查 OCR
                    提取出的题目内容。这里支持像手动新增一样边看边改，确认无误后再继续
                    AI 分析。
                </p>
            </div>

            <div class="paper-card model-selector-panel">
                <h4>选择分析模型</h4>
                <p class="meta-text">
                    OCR
                    内容确认无误后，选择下一步用于错误原因分析与建议生成的模型。
                </p>
                <AIModelSelector
                    v-model:provider-name="providerName"
                    v-model:model-name="modelName"
                />
            </div>

            <QuestionForm
                :model="draft"
                lock-source-type
                :chapter-options="aiStore.chapterOptionsWithAuto"
                chapter-placeholder="请选择章节或保持自动判断"
                @chapter-change="handleChapterChange"
            />
        </section>
    </div>
</template>

<script setup lang="ts">
import { ElMessage } from "element-plus";
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";

import { analyzeWrongQuestion, recognizeWrongQuestion } from "@/api/ai.api";
import AIModelSelector from "@/components/AIModelSelector/index.vue";
import QuestionForm from "@/components/QuestionForm/index.vue";
import UploadPanel from "@/components/UploadPanel/index.vue";
import { useAIStore } from "@/stores/ai.store";
import { useDraftStore } from "@/stores/draft.store";
import { getErrorMessage } from "@/utils/error";

const aiStore = useAIStore();
const draftStore = useDraftStore();
const router = useRouter();
const processing = ref(false);

const draft = computed(() => draftStore.currentDraft);
const activeStep = computed(() => {
    if (!draft.value?.source_image_id) {
        return 0;
    }

    if (draft.value.status === "image_uploaded") {
        return 1;
    }

    if (draft.value.status === "ocr_processing") {
        return 1;
    }

    if (draft.value.status === "ocr_reviewing") {
        return 2;
    }

    if (draft.value.status === "ai_processing") {
        return 3;
    }

    if (draft.value.status === "ai_reviewing") {
        return 4;
    }

    return 0;
});
const hasOCRResult = computed(() => Boolean(draft.value?.ocr_context));
const providerName = computed({
    get: () => draft.value?.provider_name || "",
    set: (value: string) => {
        draftStore.updateAIModelSelection(value, draft.value?.model_name || "");
    },
});
const modelName = computed({
    get: () => draft.value?.model_name || "",
    set: (value: string) => {
        draftStore.updateAIModelSelection(
            draft.value?.provider_name || "",
            value,
        );
    },
});

function resetUploadDraft() {
    draftStore.initializeDraft("upload");
}

function handleUploadSuccess(payload: { image_id: number; image_url: string }) {
    draftStore.setUploadedImage(payload.image_id, payload.image_url);
}

function handleChapterChange(value: string) {
    draftStore.updateChapterSelection(value, value.trim().length > 0);
}

async function runOCR() {
    const current = draft.value;
    if (!current?.source_image_id || !current.source_image_url) {
        ElMessage.warning("请先完成图片上传");
        return;
    }

    processing.value = true;
    current.status = "ocr_processing";

    try {
        const ocrResult = await recognizeWrongQuestion({
            image_id: current.source_image_id,
            image_url: current.source_image_url,
        });

        current.question_json = {
            question_core: ocrResult.question_core,
            standard_solution: ocrResult.standard_solution,
            wrong_solution: ocrResult.wrong_solution,
        };
        current.ocr_context = {
            ocr_confidence: ocrResult.ocr_confidence,
            uncertain_parts: ocrResult.uncertain_parts,
        };
        current.status = "ocr_reviewing";
        ElMessage.success("OCR 识别完成，请先确认识别结果");
    } catch (error) {
        current.status = "image_uploaded";
        ElMessage.error(getErrorMessage(error, "OCR 识别失败"));
    } finally {
        processing.value = false;
    }
}

async function runAnalysis() {
    const current = draft.value;
    if (!current) {
        return;
    }

    if (!current.question_json.question_core.trim()) {
        ElMessage.warning("question_core 不能为空");
        return;
    }

    processing.value = true;
    current.status = "ai_processing";

    try {
        const analysis = await analyzeWrongQuestion({
            provider_name: current.provider_name,
            model_name: current.model_name,
            chapter: current.chapter_locked
                ? (current.chapter || undefined)
                : undefined,
            question_json: current.question_json,
            ocr_context: current.ocr_context,
        });

        draftStore.applyAnalysis(analysis);
        router.push("/questions/ai-review");
    } catch (error) {
        current.status = "ocr_reviewing";
        ElMessage.error(getErrorMessage(error, "AI 分析失败"));
    } finally {
        processing.value = false;
    }
}

onMounted(async () => {
    if (
        !draftStore.currentDraft ||
        draftStore.currentDraft.flow_mode !== "upload"
    ) {
        draftStore.initializeDraft("upload");
    }

    try {
        await aiStore.fetchChapters();
    } catch {
        // 章节列表加载失败不阻断 OCR 确认页使用。
    }
});
</script>

<style scoped>
.step-card,
.status-panel,
.model-selector-panel,
.review-intro {
    padding: 20px;
}

.upload-layout {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 380px;
    gap: 20px;
}

.right-column {
    display: grid;
    gap: 12px;
    align-content: start;
}

.ocr-review-section {
    display: grid;
    gap: 16px;
}

.status-panel h3 {
    margin: 0;
}

.review-intro h3 {
    margin: 0;
}

.review-intro p {
    margin: 8px 0 0;
}

.status-actions {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    gap: 10px;
    margin-top: 20px;
}

.status-action-button {
    width: 100%;
    margin-left: 0 !important;
}

.secondary-action {
    align-self: stretch;
}

.ocr-tip {
    margin-top: 20px;
    padding: 14px;
    border-radius: 16px;
    background: rgba(30, 77, 63, 0.06);
    line-height: 1.8;
}

.model-selector-panel h4 {
    margin: 0 0 12px;
}

.model-selector-panel p {
    margin: 0 0 12px;
}

.url-text {
    word-break: break-all;
}

@media (max-width: 1080px) {
    .upload-layout {
        grid-template-columns: 1fr;
    }
}
</style>
