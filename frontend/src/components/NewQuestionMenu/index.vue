<template>
 <span class="new-question-control">
 <el-button :class="{ 'new-fab': floating }" type="primary" :aria-label="'新增错题'" @click="open=true"><el-icon><Plus/></el-icon><span>新增错题</span></el-button>
 <el-dialog append-to-body align-center v-model="open" title="新增错题" width="420px" class="new-question-dialog">
  <p class="meta-text">选择一种方式开始，随时可以保存为草稿。</p>
  <div class="entry-options"><button @click="go('/questions/upload')"><el-icon><PictureRounded/></el-icon><strong>图片录入</strong><small>上传图片，识别或手动整理</small></button><button @click="go('/questions/create')"><el-icon><EditPen/></el-icon><strong>手动录入</strong><small>填写题目，直接保存</small></button></div>
  <el-button v-if="draftStore.currentDraft" class="resume-draft" @click="resume">继续上次草稿</el-button>
  <el-button v-if="draftStore.currentDraft" text type="danger" @click="deleteDraft">删除上次草稿</el-button>
 </el-dialog>
 </span>
</template>
<script setup lang="ts">
import { ref } from 'vue'
import { ElMessageBox } from 'element-plus'
import { useRouter } from 'vue-router'
import { EditPen, PictureRounded, Plus } from '@element-plus/icons-vue'
import { useDraftStore } from '@/stores/draft.store'
defineProps<{floating?:boolean}>()
const open=ref(false),router=useRouter(),draftStore=useDraftStore()
async function go(path:string){
 if(draftStore.currentDraft){try{await ElMessageBox.confirm('已有未完成草稿。放弃草稿后开始新的错题？','已有草稿',{confirmButtonText:'放弃并新建',cancelButtonText:'继续草稿',distinguishCancelAndClose:true})}catch(action){if(action==='cancel')resume();return}draftStore.resetDraft()}
 open.value=false;draftStore.ensureDraft(path.endsWith('upload')?'upload':'manual');router.push(path)
}
async function deleteDraft(){try{await ElMessageBox.confirm('仅删除尚未保存的草稿，不影响题库里的错题。','删除草稿',{confirmButtonText:'删除草稿',cancelButtonText:'保留草稿',type:'warning'});draftStore.resetDraft()}catch{}}
function resume(){open.value=false;router.push(draftStore.currentDraft?.flow_mode==='upload'?'/questions/upload':'/questions/create')}
</script>
<style scoped>
.entry-options{display:grid;gap:12px;margin:20px 0}.entry-options button{display:grid;grid-template-columns:32px 1fr;text-align:left;align-items:center;gap:4px 12px;background:var(--paper-bg);border:1px solid var(--line);border-radius:12px;padding:20px;color:var(--text-main);cursor:pointer}.entry-options button:hover{border-color:var(--primary);background:var(--primary-soft)}.entry-options .el-icon{grid-row:span 2;font-size:26px;color:var(--primary)}.entry-options small{color:var(--text-secondary)}.resume-draft{width:100%}.new-fab{position:fixed;right:20px;bottom:calc(88px + env(safe-area-inset-bottom));height:52px;border-radius:16px;z-index:30;box-shadow:0 4px 16px rgb(0 0 0 / .15)}
</style>
