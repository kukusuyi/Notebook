<template>
  <section class="paper-card selector-card">
    <div class="selector-head">
      <div>
        <h3>AI 模型选择</h3>
        <p class="meta-text">先选厂商，再加载该厂商当前可调用的模型列表。</p>
      </div>
      <el-button text :loading="refreshing" @click="refreshAll">刷新列表</el-button>
    </div>

    <div class="selector-grid">
      <el-form-item label="模型厂商" class="field">
        <el-select
          :model-value="providerName"
          :loading="aiStore.loadingProviders"
          placeholder="请选择模型厂商"
          @update:model-value="handleProviderChange"
        >
          <el-option
            v-for="item in aiStore.providerOptions"
            :key="item.value"
            :label="item.label"
            :value="item.value"
          />
        </el-select>
      </el-form-item>

      <el-form-item label="模型名称" class="field">
        <el-select
          :model-value="modelName"
          :loading="modelsLoading"
          :disabled="!providerName"
          placeholder="请选择模型名称"
          @update:model-value="handleModelChange"
        >
          <el-option
            v-for="item in currentModels"
            :key="item.model_name"
            :label="item.model_name"
            :value="item.model_name"
          />
        </el-select>
      </el-form-item>
    </div>

    <p v-if="providerName && !modelsLoading && !currentModels.length" class="meta-text warning-text">
      当前厂商没有返回可用模型，请检查后端配置或厂商 API 权限。
    </p>
  </section>
</template>

<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { computed, onMounted, ref, watch } from 'vue'

import { useAIStore } from '@/stores/ai.store'
import { getErrorMessage } from '@/utils/error'

const props = defineProps<{
  providerName: string
  modelName: string
}>()

const emit = defineEmits<{
  'update:providerName': [value: string]
  'update:modelName': [value: string]
}>()

const aiStore = useAIStore()
const refreshing = ref(false)

const currentModels = computed(() => aiStore.getModels(props.providerName))
const modelsLoading = computed(() => aiStore.isLoadingModels(props.providerName))

async function ensureSelection() {
  const providers = await aiStore.fetchProviders()
  if (!providers.length) {
    emit('update:providerName', '')
    emit('update:modelName', '')
    return
  }

  const matchedProvider = providers.find((item) => item.provider_name === props.providerName)
  const nextProvider = matchedProvider?.provider_name || providers[0].provider_name
  if (nextProvider !== props.providerName) {
    emit('update:providerName', nextProvider)
  }

  const models = await aiStore.fetchModels(nextProvider)
  if (!models.length) {
    emit('update:modelName', '')
    return
  }

  const matchedModel = models.find((item) => item.model_name === props.modelName)
  const nextModel = matchedModel?.model_name || models[0].model_name
  if (nextModel !== props.modelName) {
    emit('update:modelName', nextModel)
  }
}

async function handleProviderChange(value: string) {
  emit('update:providerName', value)
  emit('update:modelName', '')

  try {
    const models = await aiStore.fetchModels(value, true)
    emit('update:modelName', models[0]?.model_name || '')
  } catch (error) {
    ElMessage.error(getErrorMessage(error, '加载模型列表失败'))
  }
}

function handleModelChange(value: string) {
  emit('update:modelName', value)
}

async function refreshAll() {
  refreshing.value = true
  try {
    await aiStore.fetchProviders(true)
    if (props.providerName) {
      await aiStore.fetchModels(props.providerName, true)
    }
    await ensureSelection()
    ElMessage.success('模型列表已刷新')
  } catch (error) {
    ElMessage.error(getErrorMessage(error, '刷新模型列表失败'))
  } finally {
    refreshing.value = false
  }
}

watch(
  () => props.providerName,
  async (providerName) => {
    if (!providerName) {
      return
    }

    try {
      const models = await aiStore.fetchModels(providerName)
      if (!models.find((item) => item.model_name === props.modelName)) {
        emit('update:modelName', models[0]?.model_name || '')
      }
    } catch (error) {
      ElMessage.error(getErrorMessage(error, '加载模型列表失败'))
    }
  },
)

onMounted(async () => {
  try {
    await ensureSelection()
  } catch (error) {
    ElMessage.error(getErrorMessage(error, '加载模型厂商失败'))
  }
})
</script>

<style scoped>
.selector-card {
  padding: 20px;
}

.selector-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 14px;
}

.selector-head h3 {
  margin: 0;
}

.selector-head p {
  margin: 8px 0 0;
}

.selector-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

.field {
  margin-bottom: 0;
}

.warning-text {
  margin: 4px 0 0;
  color: var(--accent);
}

@media (max-width: 720px) {
  .selector-grid {
    grid-template-columns: 1fr;
  }

  .selector-head {
    flex-direction: column;
  }
}
</style>
