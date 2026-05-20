<template>
  <div class="image-previewer paper-panel">
    <div v-if="!src" class="empty-state">暂无原始图片</div>
    <el-image v-else :src="src" :preview-src-list="[src]" fit="contain" class="image-el">
      <template #placeholder>
        <div class="empty-state">图片加载中...</div>
      </template>
      <template #error>
        <div class="empty-state">图片加载失败</div>
      </template>
    </el-image>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  src?: string
}>()
</script>

<style scoped>
.image-previewer {
  overflow: hidden;
}

.image-el {
  width: 100%;
  min-height: 280px;
  background: linear-gradient(180deg, #f8f4ed, #efe7d9);
}

.empty-state {
  display: grid;
  place-items: center;
  min-height: 280px;
  color: var(--text-secondary);
}
</style>
