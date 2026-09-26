<template>
  <section class="paper-card selector-card">
    <h3>AI 模型选择</h3>
    <p class="meta-text">日常错题分析建议使用 32B 级小模型，可按效果与响应速度调整。</p>
    <el-form-item label="已配置模型">
      <el-select :model-value="providerName" :loading="aiStore.loadingProviders" placeholder="请选择已配置模型" @update:model-value="select">
        <el-option v-for="item in aiStore.providerOptions" :key="item.value" :label="item.label" :value="item.value" />
      </el-select>
    </el-form-item>
    <p v-if="error" role="alert">{{ error }} <el-button text @click="load">重试</el-button></p>
    <p v-else-if="!aiStore.loadingProviders && !aiStore.providers.length" class="meta-text">AI 尚未配置。可以直接保存题目，或请管理员在设置中添加模型服务。</p>
  </section>
</template>
<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useAIStore } from '@/stores/ai.store'
import { getErrorMessage } from '@/utils/error'
const props = defineProps<{providerName:string;modelName:string}>()
const emit = defineEmits<{'update:providerName':[value:string];'update:modelName':[value:string]}>()
const aiStore=useAIStore(), error=ref('')
function select(name:string) {
  const item=aiStore.providers.find(p=>p.provider_name===name)
  emit('update:providerName',item?.provider_name||'')
  emit('update:modelName',item?.configured_model||'')
}
function sync(){select(aiStore.providers.some(p=>p.provider_name===props.providerName)?props.providerName:aiStore.providers[0]?.provider_name||'')}
async function load(){error.value='';try{await aiStore.fetchProviders(true);sync()}catch(e){error.value=getErrorMessage(e,'加载已配置模型失败')}}
watch(()=>[props.providerName,aiStore.providers],sync)
onMounted(load)
</script>
<style scoped>
.selector-card{padding:20px}.selector-card h3{margin:0}.selector-card p{margin:12px 0 16px}.el-select{width:100%}
</style>
