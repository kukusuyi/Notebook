<template><el-dialog v-model="updateVisible" title="发现新版本" width="min(520px, 92vw)"><template v-if="updateInfo"><p>当前电脑服务 {{updateInfo.current_version}} → {{updateInfo.version}}</p><p>更新后，连接此电脑的网页也将使用新版本。</p><pre class="release-notes">{{updateInfo.description||'暂无更新说明'}}</pre><p v-if="!updateInfo.download_url">暂未提供此平台的安装包。</p><a :href="updateInfo.download_url||updateInfo.release_url" target="_blank" rel="noopener noreferrer">{{updateInfo.download_url?'下载对应平台安装包':'查看发布说明'}}</a></template><template #footer><el-button @click="updateVisible=false">稍后再说</el-button></template></el-dialog></template>
<script setup lang="ts">
import {onMounted,onUnmounted} from 'vue'
import {checkUpdate,updateVisible,updateInfo} from '@/update/updates'
let timer:ReturnType<typeof setInterval>
onMounted(()=>{void checkUpdate();timer=setInterval(()=>void checkUpdate(),6*3600000)})
onUnmounted(()=>clearInterval(timer))
</script>
<style scoped>.release-notes{white-space:pre-wrap;max-height:45vh;overflow:auto;font:inherit}</style>
