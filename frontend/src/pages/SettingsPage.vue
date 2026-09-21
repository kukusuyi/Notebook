<template>
  <div class="page-shell">
    <header class="page-header"><div><h2 class="page-title">服务与设置</h2><p>数据保存在运行 Notebook 的电脑上；手机填写下方局域网地址后登录。</p></div></header>
    <el-alert v-if="error" :title="error" type="error" :closable="false" role="alert" />
    <section class="paper-card panel"><h3>连接地址</h3><div v-for="url in status.urls" :key="url" class="address"><code>{{url}}</code><el-button @click="copy(url)">复制地址</el-button></div><p>手机请选择非 127.0.0.1 的地址，并连接同一局域网。连接失败时检查电脑防火墙。</p></section>
    <section class="paper-card panel"><h3>相似题索引</h3><p>{{status.embedding_enabled?'已启用':'未配置模型，基础录题功能可正常使用'}} · 待处理 {{jobs.pending||0}} · 已完成 {{jobs.done||0}} · 待重试 {{jobs.failed||0}}</p><el-button @click="retry">重试失败任务</el-button><el-button @click="load">刷新状态</el-button></section>
    <template v-if="settings">
      <section class="paper-card panel"><h3>模型服务</h3><p>密钥只保存在服务端。显示 __KEEP__ 表示保留已有密钥；清空密钥可停用 OCR 或 Embedding。</p>
        <el-form label-position="top">
          <h4>OCR（通义千问视觉模型）</h4><el-form-item label="模型"><el-input v-model="settings.ocr.model" placeholder="qwen3.6-plus" /></el-form-item><el-form-item label="API Key"><el-input v-model="settings.ocr.api_key" type="password" show-password /></el-form-item>
          <h4>AI 分析模型</h4>
          <div v-for="(m,i) in settings.models" :key="i" class="model"><el-form-item label="服务名称"><el-input v-model="m.name" /></el-form-item><el-form-item label="接口地址"><el-input v-model="m.base_url" placeholder="https://example.com/v1" /></el-form-item><el-form-item label="模型"><el-input v-model="m.model" /></el-form-item><el-form-item label="API Key"><el-input v-model="m.api_key" type="password" show-password /></el-form-item><el-button type="danger" @click="settings.models.splice(i,1)">移除模型</el-button></div>
          <el-button @click="settings.models.push({name:'',provider_type:'openai_compatible',base_url:'',model:'',api_key:''})">添加模型服务</el-button>
          <h4>Embedding 相似题模型</h4><el-form-item label="接口地址"><el-input v-model="settings.embedding.base_url" /></el-form-item><el-form-item label="模型"><el-input v-model="settings.embedding.model" /></el-form-item><el-form-item label="API Key"><el-input v-model="settings.embedding.api_key" type="password" show-password /></el-form-item>
          <el-alert title="更换 Embedding 模型或地址后会重新生成向量，可能产生模型调用费用。" type="info" :closable="false" />
          <el-form-item label="APK 下载地址（可选）"><el-input v-model="settings.download_url" /></el-form-item>
          <el-form-item label="允许用户自行注册"><el-switch v-model="settings.registration_enabled" /></el-form-item>
          <el-button type="primary" :loading="busy" @click="save">保存设置</el-button><el-button :loading="busy" @click="test">测试模型连接</el-button>
          <p v-for="(value,key) in results" :key="key">{{key}}：{{value}}</p>
        </el-form>
      </section>
      <section class="paper-card panel"><h3>用户管理</h3><el-table :data="users"><el-table-column prop="username" label="用户名"/><el-table-column prop="email" label="邮箱"/><el-table-column prop="role" label="角色"/></el-table>
        <el-form label-position="top" @submit.prevent="createUser"><el-form-item label="新用户名称"><el-input v-model="user.username"/></el-form-item><el-form-item label="邮箱"><el-input v-model="user.email"/></el-form-item><el-form-item label="密码"><el-input v-model="user.password" type="password" show-password/></el-form-item><el-button native-type="submit" :loading="busy">创建用户</el-button></el-form>
      </section>
    </template>
    <el-alert v-else title="模型配置与用户管理仅管理员可用。未配置 AI 时仍可手动录入、上传和管理错题。" type="info" :closable="false"/>
  </div>
</template>
<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { httpGet,httpPost,httpPut } from '@/api/http'
type Model={name:string;provider_type:string;base_url:string;model:string;api_key:string}
type Settings={registration_enabled:boolean;ocr:{name:string;model:string;api_key:string};models:Model[];embedding:Omit<Model,'name'>;download_url:string}
const status=ref<{urls:string[];embedding_enabled:boolean}>({urls:[],embedding_enabled:false}),settings=ref<Settings|null>(null),jobs=ref<Record<string,number>>({}),users=ref<any[]>([]),results=ref<Record<string,string>>({}),error=ref(''),busy=ref(false)
const user=reactive({username:'',email:'',password:''})
async function load(){try{status.value=await httpGet('/api/v1/system/status');jobs.value=await httpGet('/api/v1/vector-jobs');try{settings.value=await httpGet('/api/v1/admin/settings');users.value=await httpGet('/api/v1/admin/users')}catch{settings.value=null}}catch(e){error.value=(e as Error).message}}
async function act(fn:()=>Promise<void>){busy.value=true;error.value='';try{await fn()}catch(e){error.value=(e as Error).message}finally{busy.value=false}}
async function save(){await act(async()=>{await httpPut('/api/v1/admin/settings',settings.value);ElMessage.success('设置已保存');await load()})}
async function test(){await act(async()=>{results.value=await httpPost('/api/v1/admin/settings/test',settings.value)})}
async function retry(){await act(async()=>{await httpPost('/api/v1/vector-jobs',{});await load()})}
async function createUser(){await act(async()=>{await httpPost('/api/v1/admin/users',user);user.password='';ElMessage.success('用户已创建');await load()})}
async function copy(text:string){try{await navigator.clipboard.writeText(text);ElMessage.success('地址已复制')}catch{ElMessage.info('请选中地址手动复制')}}
onMounted(load)
</script>
<style scoped>.panel{padding:24px;margin-bottom:20px}.address{display:flex;gap:16px;align-items:center;margin:12px 0;flex-wrap:wrap}.model{padding:16px;border:1px solid var(--border-color,#ddd);border-radius:12px;margin-bottom:16px}h4{margin-top:24px}</style>
