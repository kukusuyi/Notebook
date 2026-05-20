<template>
    <div class="page-shell">
        <header class="page-header">
            <div>
                <h2 class="page-title">手动新增错题</h2>
            </div>
            <div class="header-actions">
                <el-button @click="resetDraft">清空草稿</el-button>
                <el-button
                    type="primary"
                    :loading="submitting"
                    @click="analyzeDraft"
                >
                    继续 AI 分析
                </el-button>
            </div>
        </header>

        <section class="paper-card mode-card">
            <div class="mode-row">
                <el-radio-group v-model="editorMode">
                    <el-radio-button label="form">表单模式</el-radio-button>
                    <el-radio-button label="json">JSON 模式</el-radio-button>
                </el-radio-group>
            </div>
        </section>

        <AIModelSelector
            v-if="draft"
            v-model:provider-name="providerName"
            v-model:model-name="modelName"
        />

        <QuestionForm
            v-if="draft && editorMode === 'form'"
            :model="draft"
            :tag-options="tagStore.groupedOptions"
        />

        <section v-else-if="draft" class="json-mode-grid">
            <QuestionJsonEditor
                v-model="draft.question_json"
                @validation-change="jsonValid = $event"
            />
            <div class="paper-card side-card">
                <div class="side-head">
                    <h3>可选图片绑定</h3>
                    <p class="meta-text">
                        先上传到文件服务，后续保存正式错题时自动带上图片信息。
                    </p>
                </div>
                <UploadPanel
                    :uploaded-image="
                        draft
                            ? {
                                  image_id: draft.source_image_id,
                                  image_url: draft.source_image_url,
                              }
                            : undefined
                    "
                    @success="handleImageUploaded"
                />
            </div>
        </section>

        <section
            v-if="draft && editorMode === 'form'"
            class="paper-card upload-card"
        >
            <div class="side-head">
                <h3>可选图片绑定</h3>
                <p class="meta-text">
                    上传成功后会自动写入 `图片 ID` 与 `图片 URL`。
                </p>
            </div>
            <UploadPanel
                :uploaded-image="{
                    image_id: draft.source_image_id,
                    image_url: draft.source_image_url,
                }"
                @success="handleImageUploaded"
            />
        </section>
    </div>
</template>

<script setup lang="ts">
import { ElMessage } from "element-plus";
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";

import { analyzeWrongQuestion } from "@/api/ai.api";
import AIModelSelector from "@/components/AIModelSelector/index.vue";
import QuestionForm from "@/components/QuestionForm/index.vue";
import QuestionJsonEditor from "@/components/QuestionJsonEditor/index.vue";
import UploadPanel from "@/components/UploadPanel/index.vue";
import { useDraftStore } from "@/stores/draft.store";
import { useTagStore } from "@/stores/tag.store";
import { getErrorMessage } from "@/utils/error";

const router = useRouter();
const draftStore = useDraftStore();
const tagStore = useTagStore();
const editorMode = ref<"form" | "json">("form");
const jsonValid = ref(true);
const submitting = ref(false);

const draft = computed(() => draftStore.currentDraft);
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

function resetDraft() {
    draftStore.initializeDraft("manual");
}

function handleImageUploaded(payload: { image_id: number; image_url: string }) {
    const current = draftStore.ensureDraft("manual");
    current.source_image_id = payload.image_id;
    current.source_image_url = payload.image_url;
    ElMessage.success("图片已绑定到当前草稿");
}

async function analyzeDraft() {
    const current = draft.value;
    if (!current) {
        return;
    }

    if (!jsonValid.value) {
        ElMessage.warning("请先修复 JSON 格式错误");
        return;
    }

    if (!current.question_json.question_core.trim()) {
        ElMessage.warning("question_core 不能为空");
        return;
    }

    if (!current.subject.trim()) {
        ElMessage.warning("subject 不能为空");
        return;
    }

    if (!current.provider_name.trim() || !current.model_name.trim()) {
        ElMessage.warning("请先选择模型厂商和模型名称");
        return;
    }

    current.status = "ai_processing";
    submitting.value = true;

    try {
        const result = await analyzeWrongQuestion({
            provider_name: current.provider_name,
            model_name: current.model_name,
            question_json: current.question_json,
        });

        draftStore.applyAnalysis(result);
        router.push("/questions/ai-review");
    } catch (error) {
        ElMessage.error(getErrorMessage(error, "AI 分析失败"));
    } finally {
        submitting.value = false;
    }
}

onMounted(async () => {
    if (
        !draftStore.currentDraft ||
        draftStore.currentDraft.flow_mode !== "manual"
    ) {
        draftStore.initializeDraft("manual");
    }

    try {
        await tagStore.fetchTags();
    } catch {
        // 标签选项加载失败不阻断录入。
    }
});
</script>

<style scoped>
.header-actions,
.mode-row {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
    align-items: center;
}

.mode-card,
.upload-card,
.side-card {
    padding: 20px;
}

.json-mode-grid {
    display: grid;
    grid-template-columns: minmax(0, 1.1fr) minmax(280px, 0.9fr);
    gap: 20px;
}

.side-head h3 {
    margin: 0;
}

.side-head p {
    margin: 8px 0 16px;
}

@media (max-width: 1080px) {
    .json-mode-grid {
        grid-template-columns: 1fr;
    }
}
</style>
