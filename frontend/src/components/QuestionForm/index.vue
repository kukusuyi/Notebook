<template>
    <div class="question-form-grid">
        <section class="paper-card form-card">
            <div class="section-head">
                <h3>题目基础信息</h3>
                <p>先整理标准错题 JSON，再补充学科、章节和图片绑定信息。</p>
            </div>

            <el-form label-position="top">
                <el-form-item label="题目主干">
                    <el-input
                        v-model="model.question_json.question_core"
                        type="textarea"
                        :autosize="{ minRows: 4, maxRows: 10 }"
                        placeholder="支持普通文本与 LaTeX 混排"
                    />
                </el-form-item>

                <el-form-item label="标准题解">
                    <el-input
                        v-model="model.question_json.standard_solution"
                        type="textarea"
                        :autosize="{ minRows: 4, maxRows: 10 }"
                        placeholder="可以为空"
                    />
                </el-form-item>

                <el-form-item label="错误解法 / 错误思路">
                    <el-input
                        v-model="model.question_json.wrong_solution"
                        type="textarea"
                        :autosize="{ minRows: 4, maxRows: 10 }"
                        placeholder="可以为空，但建议保留学生原始错误过程"
                    />
                </el-form-item>

                <div class="form-row">
                    <el-form-item label="学科" class="grow">
                        <el-input
                            v-model="model.subject"
                            placeholder="例如：math / 高等数学"
                        />
                    </el-form-item>
                    <el-form-item label="章节" class="grow">
                        <el-select
                            v-if="chapterOptions.length"
                            v-model="model.chapter"
                            :placeholder="chapterPlaceholder"
                            @change="emit('chapter-change', model.chapter)"
                        >
                            <el-option
                                v-for="item in chapterOptions"
                                :key="item.value"
                                :label="item.label"
                                :value="item.value"
                            />
                        </el-select>
                        <el-input
                            v-else
                            v-model="model.chapter"
                            placeholder="例如：函数极限与连续"
                            @input="emit('chapter-change', model.chapter)"
                        />
                    </el-form-item>
                </div>

                <div class="form-row">
                    <el-form-item label="来源类型" class="grow">
                        <el-select v-model="model.source_type" :disabled="lockSourceType">
                            <el-option label="手动录入" value="manual" />
                            <el-option label="图片识别" value="image" />
                            <el-option label="导入" value="import" />
                        </el-select>
                    </el-form-item>
                    <el-form-item label="掌握状态" class="grow">
                        <el-select v-model="model.mastery_status">
                            <el-option label="未掌握" value="unmastered" />
                            <el-option label="学习中" value="learning" />
                            <el-option label="已掌握" value="mastered" />
                        </el-select>
                    </el-form-item>
                </div>

                <el-form-item label="图片 URL">
                    <el-input
                        v-model="model.source_image_url"
                        placeholder="上传成功后自动填充"
                    />
                </el-form-item>

                <el-form-item label="图片 ID">
                    <el-input
                        :model-value="model.source_image_id ? String(model.source_image_id) : ''"
                        placeholder="上传成功后自动填充"
                        readonly
                    />
                </el-form-item>

                <template v-if="showAnalysisFields">
                    <div class="section-divider"></div>

                    <div class="section-head compact">
                        <h3>AI 分析结果</h3>
                        <p>
                            标签与摘要都允许用户确认、修改，再保存到正式错题。
                        </p>
                    </div>

                    <el-form-item label="语义摘要 semantic_summary">
                        <el-input
                            v-model="model.semantic_summary"
                            type="textarea"
                            :autosize="{ minRows: 3, maxRows: 8 }"
                        />
                    </el-form-item>

                    <el-form-item label="错因摘要 mistake_summary">
                        <el-input
                            v-model="model.mistake_summary"
                            type="textarea"
                            :autosize="{ minRows: 3, maxRows: 8 }"
                        />
                    </el-form-item>

                    <div class="form-row tags-row">
                        <el-form-item label="知识点标签" class="grow">
                            <el-select
                                v-model="model.tags.knowledge_points"
                                multiple
                                filterable
                                allow-create
                                default-first-option
                            >
                                <el-option
                                    v-for="item in tagOptions.knowledge_points ||
                                    []"
                                    :key="item"
                                    :label="item"
                                    :value="item"
                                />
                            </el-select>
                        </el-form-item>

                        <el-form-item label="题型标签" class="grow">
                            <el-select
                                v-model="model.tags.problem_type"
                                multiple
                                filterable
                                allow-create
                                default-first-option
                            >
                                <el-option
                                    v-for="item in tagOptions.problem_type ||
                                    []"
                                    :key="item"
                                    :label="item"
                                    :value="item"
                                />
                            </el-select>
                        </el-form-item>
                    </div>

                    <div class="form-row tags-row">
                        <el-form-item label="解法标签" class="grow">
                            <el-select
                                v-model="model.tags.method"
                                multiple
                                filterable
                                allow-create
                                default-first-option
                            >
                                <el-option
                                    v-for="item in tagOptions.method || []"
                                    :key="item"
                                    :label="item"
                                    :value="item"
                                />
                            </el-select>
                        </el-form-item>

                        <el-form-item label="错因标签" class="grow">
                            <el-select
                                v-model="model.tags.mistake_reason"
                                multiple
                                filterable
                                allow-create
                                default-first-option
                            >
                                <el-option
                                    v-for="item in tagOptions.mistake_reason ||
                                    []"
                                    :key="item"
                                    :label="item"
                                    :value="item"
                                />
                            </el-select>
                        </el-form-item>
                    </div>
                </template>
            </el-form>
        </section>

        <section class="preview-column">
            <div class="preview-stack">
                <div class="paper-card preview-card">
                    <div class="preview-head">题目预览</div>
                    <LatexRenderer
                        :content="model.question_json.question_core"
                        allow-source-toggle
                    />
                </div>

                <div class="paper-card preview-card">
                    <div class="preview-head">标准题解预览</div>
                    <LatexRenderer
                        :content="model.question_json.standard_solution"
                        allow-source-toggle
                    />
                </div>

                <div class="paper-card preview-card">
                    <div class="preview-head">错误解法预览</div>
                    <LatexRenderer
                        :content="model.question_json.wrong_solution"
                        allow-source-toggle
                    />
                </div>

                <div v-if="model.source_image_url" class="paper-card preview-card">
                    <div class="preview-head">原始图片预览</div>
                    <ImagePreviewer :src="model.source_image_url" />
                </div>
            </div>
        </section>
    </div>
</template>

<script setup lang="ts">
import ImagePreviewer from "@/components/ImagePreviewer/index.vue";
import LatexRenderer from "@/components/LatexRenderer/index.vue";
import type { OptionItem } from "@/types/common";
import type { QuestionDraft } from "@/types/question";

const emit = defineEmits<{
    "chapter-change": [value: string];
}>();

withDefaults(
    defineProps<{
        model: QuestionDraft;
        showAnalysisFields?: boolean;
        tagOptions?: Partial<Record<keyof QuestionDraft["tags"], string[]>>;
        lockSourceType?: boolean;
        chapterOptions?: OptionItem[];
        chapterPlaceholder?: string;
    }>(),
    {
        showAnalysisFields: false,
        tagOptions: () => ({}),
        lockSourceType: false,
        chapterOptions: () => [],
        chapterPlaceholder: "例如：函数极限与连续",
    },
);
</script>

<style scoped>
.question-form-grid {
    display: grid;
    grid-template-columns: minmax(0, 1.2fr) minmax(0, 0.8fr);
    gap: 20px;
}

.form-card,
.preview-card {
    padding: 20px;
}

.section-head h3,
.preview-head {
    margin: 0;
    font-size: 20px;
}

.section-head p {
    margin: 8px 0 0;
    color: var(--text-secondary);
}

.section-head.compact {
    margin-bottom: 14px;
}

.form-row {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 16px;
}

.grow {
    width: 100%;
}

.section-divider {
    margin: 8px 0 18px;
    border-top: 1px dashed var(--line-strong);
}

.preview-column,
.preview-stack {
    display: grid;
    gap: 16px;
    align-content: start;
}

.preview-head {
    margin-bottom: 12px;
}

@media (max-width: 1080px) {
    .question-form-grid {
        grid-template-columns: 1fr;
    }
}

@media (max-width: 720px) {
    .form-row {
        grid-template-columns: 1fr;
    }
}
</style>
