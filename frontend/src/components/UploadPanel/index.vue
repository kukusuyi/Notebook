<template>
    <div class="upload-panel paper-card">
        <el-upload
            drag
            action="#"
            :auto-upload="true"
            :before-upload="beforeUpload"
            :show-file-list="false"
            :http-request="handleUploadRequest"
            accept=".png,.jpg,.jpeg,.webp"
            class="upload-inner"
        >
            <el-icon class="upload-icon"><UploadFilled /></el-icon>
            <div class="el-upload__text">
                拖拽图片到这里，或 <em>点击上传</em>
            </div>
            <template #tip>
                <div class="meta-text">
                    支持 JPG / PNG / WebP，仅支持上传单张图片。
                </div>
            </template>
        </el-upload>

        <div v-if="previewURL" class="preview-zone">
            <el-image :src="previewURL" fit="contain" class="preview-image">
                <template #placeholder>
                    <div class="preview-state">图片加载中...</div>
                </template>
                <template #error>
                    <div class="preview-state">
                        当前图片地址无法访问
                        <span v-if="isLegacyStaticURL" class="meta-text"
                            >，检测到旧版 `/static` 地址，建议重新上传</span
                        >
                    </div>
                </template>
            </el-image>
        </div>
    </div>
</template>

<script setup lang="ts">
import { UploadFilled } from "@element-plus/icons-vue";
import { ElMessage } from "element-plus";
import type {
    UploadProps,
    UploadRawFile,
    UploadRequestOptions,
} from "element-plus";
import { computed, onBeforeUnmount, ref, watch } from "vue";

import { uploadImage } from "@/api/file.api";
import type { UploadedImage } from "@/types/file";
import { getErrorMessage } from "@/utils/error";

const props = withDefaults(
    defineProps<{
        uploadedImage?: Partial<UploadedImage> | null;
        maxSizeMB?: number;
    }>(),
    {
        uploadedImage: null,
        maxSizeMB: 16,
    },
);

const emit = defineEmits<{
    (event: "success", value: UploadedImage): void;
}>();

const previewURL = ref("");
const objectURL = ref<string | null>(null);
const isLegacyStaticURL = computed(() => previewURL.value.includes("/static/"));

watch(
    () => props.uploadedImage?.image_url,
    (value) => {
        if (!objectURL.value) {
            previewURL.value = value || "";
        }
    },
    { immediate: true },
);

function clearObjectURL() {
    if (!objectURL.value) {
        return;
    }

    URL.revokeObjectURL(objectURL.value);
    objectURL.value = null;
}

const beforeUpload: UploadProps["beforeUpload"] = (file) => {
    const rawFile = file as UploadRawFile;
    const allowedTypes = ["image/png", "image/jpeg", "image/webp"];
    const byExtension = /\.(png|jpe?g|webp)$/i.test(rawFile.name);
    const isValidImage = allowedTypes.includes(rawFile.type) || byExtension;

    if (!isValidImage) {
        ElMessage.warning("仅支持 JPG / PNG / WebP 图片");
        return false;
    }

    if (rawFile.size > props.maxSizeMB * 1024 * 1024) {
        ElMessage.warning(`图片大小不能超过 ${props.maxSizeMB}MB`);
        return false;
    }

    return true;
};

async function handleUploadRequest(options: UploadRequestOptions) {
    const file = options.file;
    clearObjectURL();
    objectURL.value = URL.createObjectURL(file);
    previewURL.value = objectURL.value;

    try {
        const result = await uploadImage(file);
        clearObjectURL();
        previewURL.value = result.image_url;
        options.onSuccess?.(result);
        emit("success", result);
        ElMessage.success("图片上传成功");
    } catch (error) {
        options.onError?.(error as never);
        ElMessage.error(getErrorMessage(error, "图片上传失败"));
    }
}

onBeforeUnmount(() => {
    clearObjectURL();
});
</script>

<style scoped>
.upload-panel {
    padding: 20px;
}

:deep(.upload-inner .el-upload-dragger) {
    border-radius: 20px;
    border: 1px dashed rgba(30, 77, 63, 0.25);
    background: linear-gradient(
        180deg,
        rgba(30, 77, 63, 0.05),
        rgba(192, 103, 44, 0.04)
    );
}

.upload-icon {
    font-size: 34px;
    color: var(--primary);
}

.preview-zone {
    margin-top: 18px;
    border-radius: 18px;
    overflow: hidden;
    border: 1px solid var(--line);
}

.preview-image {
    width: 100%;
    max-height: 420px;
    background: #f7f3ea;
}
.preview-state {
    min-height: 240px;
    display: grid;
    place-items: center;
    text-align: center;
    padding: 24px;
    color: var(--text-secondary);
}
</style>
