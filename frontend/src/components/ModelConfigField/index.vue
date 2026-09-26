<template>
  <div class="model-field">
    <el-button :loading="loading" @click="load">{{ error ? '重试加载模型' : '连接并加载模型' }}</el-button>
    <p v-if="error" role="alert" class="error">{{ error }}</p>
    <p v-else-if="loaded" role="status" class="meta-text">{{ models.length ? '连接成功，请选择模型后保存。' : '服务未返回模型，可手动输入模型名称。' }}</p>
    <el-form-item :label="kind === 'ocr' ? '视觉模型' : '模型名称'">
      <el-select :model-value="modelValue" filterable allow-create default-first-option placeholder="选择或手动输入模型名称" @update:model-value="$emit('update:modelValue',$event)">
        <el-option v-for="m in choices" :key="m" :label="m" :value="m" />
      </el-select>
    </el-form-item>
    <p class="meta-text">可手动输入服务商提供的模型 ID。{{kind==='ocr'?'图片识别需选择支持图片输入的模型。':''}}</p>
  </div>
</template>
<script setup lang="ts">
import {computed,ref,watch} from 'vue'
import {httpPost} from '@/api/http'
import {getErrorMessage} from '@/utils/error'
const props=defineProps<{kind:'ocr'|'analysis';modelValue:string;config:Record<string,string>;savedName?:string}>()
defineEmits<{'update:modelValue':[value:string]}>()
const models=ref<string[]>([]),loading=ref(false),loaded=ref(false),error=ref('')
let sequence=0
const choices=computed(()=>Array.from(new Set([props.modelValue,...models.value].filter(Boolean))))
watch(()=>[props.config.api_key,props.config.base_url,props.config.provider_type],()=>{sequence++;loading.value=false;loaded.value=false;models.value=[];error.value=''})
async function load(){const request=++sequence;loading.value=true;error.value='';try{const result=await httpPost<{models:string[]}>('/api/v1/admin/settings/models',{kind:props.kind,saved_name:props.savedName,config:props.config});if(request===sequence){models.value=result.models;loaded.value=true}}catch(e){if(request===sequence)error.value=getErrorMessage(e,'加载失败，可重试或手动填写模型名称。')}finally{if(request===sequence)loading.value=false}}
</script>
<style scoped>.model-field{margin-top:12px}.model-field .el-form-item{margin-top:16px}.el-select{width:100%}.error{color:var(--accent)}.meta-text{font-size:14px}</style>
