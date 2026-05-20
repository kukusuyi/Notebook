<template>
    <div class="page-shell">
        <header class="page-header">
            <div>
                <h2 class="page-title">标签管理</h2>
                <p class="page-subtitle">当前提供列表、筛选、创建和删除</p>
            </div>
            <el-button type="primary" @click="createDialogVisible = true"
                >新增标签</el-button
            >
        </header>

        <section class="paper-card filter-card">
            <div class="filter-row">
                <el-select
                    v-model="filters.tag_type"
                    clearable
                    placeholder="标签类型"
                >
                    <el-option label="知识点" value="knowledge_point" />
                    <el-option label="题型" value="problem_type" />
                    <el-option label="解法" value="method" />
                    <el-option label="错因" value="mistake_reason" />
                </el-select>
                <el-input
                    v-model="filters.keyword"
                    placeholder="标签名称关键词"
                />
                <el-button type="primary" @click="loadTags">查询</el-button>
            </div>
        </section>

        <section class="paper-card table-card">
            <el-table :data="tags" v-loading="loading">
                <el-table-column prop="tag_id" label="ID" width="90" />
                <el-table-column prop="tag_name" label="标签名称" />
                <el-table-column prop="tag_type" label="标签类型" width="160" />
                <el-table-column
                    prop="usage_count"
                    label="使用次数"
                    width="120"
                />
                <el-table-column label="状态" width="120">
                    <template #default="{ row }">
                        <el-tag :type="row.is_active ? 'success' : 'info'">
                            {{ row.is_active ? "active" : "inactive" }}
                        </el-tag>
                    </template>
                </el-table-column>
                <el-table-column label="操作" width="140">
                    <template #default="{ row }">
                        <el-button
                            type="danger"
                            text
                            @click="removeTag(row.tag_id)"
                            >删除</el-button
                        >
                    </template>
                </el-table-column>
            </el-table>
        </section>

        <el-dialog v-model="createDialogVisible" title="新增标签" width="420px">
            <el-form label-position="top">
                <el-form-item label="标签名称">
                    <el-input v-model="createForm.tag_name" />
                </el-form-item>
                <el-form-item label="标签类型">
                    <el-select v-model="createForm.tag_type">
                        <el-option label="知识点" value="knowledge_point" />
                        <el-option label="题型" value="problem_type" />
                        <el-option label="解法" value="method" />
                        <el-option label="错因" value="mistake_reason" />
                    </el-select>
                </el-form-item>
            </el-form>
            <template #footer>
                <el-button @click="createDialogVisible = false">取消</el-button>
                <el-button
                    type="primary"
                    :loading="creating"
                    @click="submitCreate"
                    >创建</el-button
                >
            </template>
        </el-dialog>
    </div>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from "element-plus";
import { onMounted, reactive, ref } from "vue";

import { createTag, deleteTag, listTags } from "@/api/tag.api";
import type { TagItem, TagType } from "@/types/tag";
import { getErrorMessage } from "@/utils/error";

const tags = ref<TagItem[]>([]);
const loading = ref(false);
const creating = ref(false);
const createDialogVisible = ref(false);
const filters = reactive({
    tag_type: "",
    keyword: "",
});
const createForm = reactive<{ tag_name: string; tag_type: TagType }>({
    tag_name: "",
    tag_type: "knowledge_point",
});

async function loadTags() {
    loading.value = true;
    try {
        tags.value = (await listTags(filters)).list;
    } catch (error) {
        ElMessage.error(getErrorMessage(error, "标签列表加载失败"));
    } finally {
        loading.value = false;
    }
}

async function submitCreate() {
    if (!createForm.tag_name.trim()) {
        ElMessage.warning("请输入标签名称");
        return;
    }

    creating.value = true;
    try {
        await createTag(createForm);
        ElMessage.success("标签创建成功");
        createDialogVisible.value = false;
        createForm.tag_name = "";
        createForm.tag_type = "knowledge_point";
        await loadTags();
    } catch (error) {
        ElMessage.error(getErrorMessage(error, "标签创建失败"));
    } finally {
        creating.value = false;
    }
}

async function removeTag(tagID: number) {
    try {
        await ElMessageBox.confirm(
            "删除标签后，用户侧将不再展示该标签。数据库仍会保留软删除记录。是否继续？",
            "确认删除标签",
            { type: "warning" },
        );

        await deleteTag(tagID);
        ElMessage.success("标签已删除");
        await loadTags();
    } catch (error) {
        if (error instanceof Error && error.message !== "cancel") {
            ElMessage.error(getErrorMessage(error, "标签删除失败"));
        }
    }
}

onMounted(loadTags);
</script>

<style scoped>
.filter-card,
.table-card {
    padding: 20px;
}

.filter-row {
    display: grid;
    grid-template-columns: 200px minmax(0, 1fr) 100px;
    gap: 16px;
}

@media (max-width: 900px) {
    .filter-row {
        grid-template-columns: 1fr;
    }
}
</style>
