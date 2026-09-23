<template>
  <el-button @click="open = true">拍照 / 图片识别答案步骤</el-button>
  <el-dialog v-model="open" append-to-body align-center title="识别答案步骤" width="min(720px, 94vw)" :close-on-click-modal="false" :close-on-press-escape="!busy" :show-close="!busy">
    <p>仅抄录图片中的答案与步骤，不解题、不改写题目。核对后再应用。</p>
    <UploadPanel v-show="!busy" :uploaded-image="image" @success="selectImage" />
    <el-button :disabled="!image || busy" :loading="busy" @click="recognize">识别答案文字</el-button>
    <el-alert v-if="error" :title="error" type="error" :closable="false" />
    <template v-if="recognized">
      <el-alert v-if="warnings" :title="warnings" type="warning" :closable="false" />
      <el-input :disabled="busy" v-model="result" aria-label="核对答案识别结果" type="textarea" :autosize="{ minRows: 6, maxRows: 14 }" />
    </template>
    <template #footer>
      <el-button :disabled="busy" @click="open = false">取消</el-button>
      <el-button v-if="modelValue.trim()" :disabled="busy || !result.trim()" @click="apply(false)">替换原答案</el-button>
      <el-button type="primary" :disabled="busy || !result.trim()" @click="apply(true)">{{ modelValue.trim() ? '追加到答案' : '应用答案' }}</el-button>
    </template>
  </el-dialog>
</template>
<script setup lang="ts">
import { ref } from 'vue'
import { ElMessageBox } from 'element-plus'
import UploadPanel from '@/components/UploadPanel/index.vue'
import { recognizeWrongQuestion } from '@/api/ai.api'
import { getErrorMessage } from '@/utils/error'
import type { UploadedImage } from '@/types/file'
const props = defineProps<{ modelValue: string }>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()
const open = ref(false), busy = ref(false), recognized = ref(false)
const image = ref<UploadedImage | null>(null)
const result = ref(''), error = ref(''), warnings = ref('')
function selectImage(value: UploadedImage) { image.value = value; result.value = ''; recognized.value = false; error.value = ''; warnings.value = '' }
async function recognize() {
  if (!image.value || busy.value) return
  busy.value = true; error.value = ''
  try {
    const response = await recognizeWrongQuestion({ image_url: image.value.image_url, image_id: image.value.image_id, purpose: 'solution' })
    result.value = response.standard_solution || ''; recognized.value = true
    warnings.value = response.uncertain_parts?.join('；') || (response.ocr_confidence === 'low' ? '图片不够清晰，请仔细核对。' : '')
    if (!result.value.trim()) error.value = '未识别到答案文字，请裁剪答案区域后重试，或手动填写。'
  } catch (e) { error.value = getErrorMessage(e, '答案识别失败，请重试或手动填写。') }
  finally { busy.value = false }
}
async function apply(append: boolean) {
  if (busy.value || !result.value.trim()) return
  if (!append && props.modelValue.trim()) {
    try { await ElMessageBox.confirm('将用核对后的识别文字替换当前标准答案。', '替换答案', { confirmButtonText: '替换', cancelButtonText: '取消' }) } catch { return }
  }
  emit('update:modelValue', append && props.modelValue.trim() ? `${props.modelValue.trim()}\n\n${result.value.trim()}` : result.value.trim())
  open.value = false; result.value = ''; recognized.value = false; image.value = null
}
</script>
<style scoped>
p { color: var(--text-secondary); }
:deep(.el-alert), :deep(.el-textarea), :deep(.upload-panel) { margin-bottom: 12px; }
</style>
