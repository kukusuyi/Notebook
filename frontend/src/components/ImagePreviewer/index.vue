<template>
  <div class="image-previewer paper-panel">
    <div v-if="!src" class="empty-state">暂无原始图片</div>
    <el-image v-else :src="src" :preview-src-list="[src]" fit="contain" preview-teleported class="image-el">
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
  display: block;
  line-height: 0;
  background: var(--paper-bg);
}

.image-el :deep(.el-image__inner) { display:block; width:100%; height:auto; max-height:60vh; object-fit:contain; }

.empty-state {
  display: grid;
  place-items: center;
  min-height: 96px;
  color: var(--text-secondary);
}
</style>
