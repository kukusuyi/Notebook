<template>
  <div class="page-shell">
    <header class="page-header">
      <div>
        <h2 class="page-title">前端设置</h2>
        <p class="page-subtitle">
          先保留最关键的联调配置。当前页面以本地存储为主，不依赖专门后端设置接口。
        </p>
      </div>
    </header>

    <section class="settings-grid">
      <article class="paper-card settings-card">
        <h3>接口配置</h3>
        <el-form label-position="top">
          <el-form-item label="API Base URL">
            <el-input v-model="apiBaseURL" placeholder="例如 http://localhost:8080" />
          </el-form-item>
          <el-form-item>
            <el-button type="primary" @click="saveApiBaseURL">保存并刷新提示</el-button>
          </el-form-item>
        </el-form>
      </article>

      <article class="paper-card settings-card">
        <h3>说明</h3>
        <ul class="notes">
          <li>当前请求层会优先读取本地存储里的 API Base URL。</li>
          <li>修改后刷新页面即可让新配置生效。</li>
          <li>LaTeX 渲染默认使用 KaTeX 自动识别 `$...$`、`$$...$$`、`\(...\)`、`\[...\]`。</li>
          <li>AI 分析确认页和手动录入页草稿会保存在 `sessionStorage`，关闭标签页后自动失效。</li>
        </ul>
      </article>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { ref } from 'vue'

const apiBaseURL = ref(
  window.localStorage.getItem('math-notebook:api-base-url') || 'http://localhost:8080',
)

function saveApiBaseURL() {
  window.localStorage.setItem('math-notebook:api-base-url', apiBaseURL.value.trim())
  ElMessage.success('设置已保存，刷新页面后会使用新的 API Base URL')
}
</script>

<style scoped>
.settings-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(320px, 0.8fr);
  gap: 20px;
}

.settings-card {
  padding: 20px;
}

.settings-card h3 {
  margin: 0 0 16px;
}

.notes {
  margin: 0;
  padding-left: 18px;
  color: var(--text-secondary);
  line-height: 1.9;
}

@media (max-width: 960px) {
  .settings-grid {
    grid-template-columns: 1fr;
  }
}
</style>
