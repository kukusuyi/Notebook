<template>
 <div class="upload-panel paper-card">
  <el-upload drag action="#" :auto-upload="false" :show-file-list="false" :on-change="selectFile" :disabled="busy" accept="image/png,image/jpeg,image/webp" class="upload-inner"><el-icon class="upload-icon"><UploadFilled/></el-icon><div class="el-upload__text">拖拽图片到这里，或 <em>选择图片 / 拍照</em></div><template #tip><div class="meta-text">选择后先裁剪再上传。支持 JPG / PNG / WebP。</div></template></el-upload>
  <el-alert v-if="error" :title="error" type="error" :closable="false"/>
  <div v-if="uploadedImage?.image_url" class="preview-zone"><el-image :src="uploadedImage.image_url" fit="contain" class="preview-image"/><el-button :loading="busy" @click="cropExisting">重新裁剪图片</el-button></div>
  <ImageCropDialog :open="cropping" :src="cropURL" :busy="busy" @cancel="cropping=false" @confirm="uploadCropped"/>
 </div>
</template>
<script setup lang="ts">
import {UploadFilled} from '@element-plus/icons-vue'
import {ElMessage,type UploadFile} from 'element-plus'
import {ref,onBeforeUnmount} from 'vue'
import ImageCropDialog from '@/components/ImageCropDialog/index.vue'
import {uploadImage} from '@/api/file.api'
import {getApiBaseURL} from '@/api/http'
import {getAuthToken} from '@/utils/auth'
import {getErrorMessage} from '@/utils/error'
import type {UploadedImage} from '@/types/file'
const props=withDefaults(defineProps<{uploadedImage?:Partial<UploadedImage>|null;maxSizeMB?:number}>(),{maxSizeMB:16,uploadedImage:null})
const emit=defineEmits<{(e:'success',value:UploadedImage):void}>()
const cropURL=ref(''),cropping=ref(false),busy=ref(false),error=ref('')
function showCrop(blob:Blob){if(cropURL.value)URL.revokeObjectURL(cropURL.value);cropURL.value=URL.createObjectURL(blob);cropping.value=true;error.value=''}
function selectFile(file:UploadFile){if(busy.value||!file.raw)return;if(!['image/png','image/jpeg','image/webp'].includes(file.raw.type)){error.value='请选择 JPG、PNG 或 WebP 图片。';return}if(file.raw.size>props.maxSizeMB*1024*1024){error.value=`图片不能超过 ${props.maxSizeMB} MB，请选择较小的图片。`;return}showCrop(file.raw)}
async function cropExisting(){if(busy.value||!props.uploadedImage?.image_url)return;busy.value=true;error.value='';try{const url=new URL(props.uploadedImage.image_url,getApiBaseURL());if(url.origin!==new URL(getApiBaseURL()).origin)throw new Error('旧图片不支持直接裁剪，请重新选择本机图片。');const res=await fetch(url,{credentials:'include',headers:{Authorization:`Bearer ${getAuthToken()}`}});if(!res.ok)throw {status:res.status};showCrop(await res.blob())}catch(e){error.value=getErrorMessage(e,'图片读取失败，请重新选择图片。')}finally{busy.value=false}}
async function uploadCropped(file:File){if(busy.value)return;if(file.size>props.maxSizeMB*1024*1024){error.value='裁剪结果仍然过大，请缩小裁剪范围。';return}busy.value=true;error.value='';try{const result=await uploadImage(file);emit('success',result);cropping.value=false;ElMessage.success('图片已裁剪并上传')}catch(e){error.value=getErrorMessage(e,'图片上传失败，请重试。');ElMessage.error(error.value)}finally{busy.value=false}}
onBeforeUnmount(()=>{if(cropURL.value)URL.revokeObjectURL(cropURL.value)})
</script>
<style scoped>
.upload-panel{padding:20px}:deep(.upload-inner .el-upload-dragger){border-radius:12px;border:1px dashed var(--primary);background:var(--primary-soft)}.upload-icon{font-size:34px;color:var(--primary)}.preview-zone{display:grid;justify-items:start;gap:12px;margin-top:18px}.preview-image{width:100%;max-height:360px;background:var(--app-bg)}
</style>
