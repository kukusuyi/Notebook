<template>
 <div class="layout-root" :class="{'immersive':!topLevel}">
  <aside class="sidebar">
   <RouterLink class="brand" to="/dashboard"><span class="brand-mark">∫</span><strong>题迹 <small>Questrace</small></strong></RouterLink>
   <nav class="nav-list" aria-label="主要导航"><RouterLink v-for="item in navItems" :key="item.to" :to="item.to" class="nav-item" :class="{active:isActive(item.to)}" :aria-label="item.label"><el-icon><component :is="item.icon"/></el-icon><span>{{item.label}}</span></RouterLink></nav>
   <div class="sidebar-footer"><span class="avatar">{{username.slice(0,1).toUpperCase()}}</span><span class="user-label">{{username}}</span><el-button text aria-label="退出登录" @click="handleLogout"><el-icon><SwitchButton/></el-icon></el-button></div>
  </aside>
  <div class="layout-main">
   <header class="app-toolbar"><div class="toolbar-leading"><el-button v-if="!topLevel" text aria-label="返回" @click="back"><el-icon><ArrowLeft/></el-icon></el-button><span class="toolbar-brand">题迹</span><span class="toolbar-title">{{route.meta.title}}</span></div><div class="toolbar-right"><span class="connection-status"><i/>本地学习空间</span><NewQuestionMenu v-if="addAllowed" class="desktop-add"/></div></header>
   <main id="main-content" class="content-area"><RouterView/></main>
  </div>
  <nav v-if="topLevel" class="mobile-nav" aria-label="底部导航"><RouterLink v-for="item in navItems" :key="item.to" :to="item.to" :class="{active:isActive(item.to)}"><el-icon><component :is="item.icon"/></el-icon><span>{{item.short}}</span></RouterLink></nav>
  <NewQuestionMenu v-if="topLevel&&addAllowed" floating class="mobile-add"/>
 </div>
</template>
<script setup lang="ts">
import {Collection,DataBoard,Connection,Setting,SwitchButton,ArrowLeft} from '@element-plus/icons-vue'
import {computed,onMounted} from 'vue'
import {RouterLink,RouterView,useRoute,useRouter} from 'vue-router'
import {useAuthStore} from '@/stores/auth.store'
import {useUserStore} from '@/stores/user.store'
import NewQuestionMenu from '@/components/NewQuestionMenu/index.vue'
const route=useRoute(),router=useRouter(),authStore=useAuthStore(),userStore=useUserStore()
const navItems=[{label:'学习概览',short:'概览',to:'/dashboard',icon:DataBoard},{label:'我的错题',short:'错题',to:'/questions',icon:Collection},{label:'标签管理',short:'标签',to:'/tags',icon:Connection},{label:'设置与账户',short:'我的',to:'/settings',icon:Setting}]
const topLevel=computed(()=>navItems.some(i=>i.to===route.path)),addAllowed=computed(()=>['/dashboard','/questions'].includes(route.path))
const username=computed(()=>userStore.profile?.username||authStore.authUser?.username||'学习者')
function isActive(to:string){return to==='/questions'?route.path.startsWith(to):route.path===to}
function back(){if(window.history.state.back)router.back();else router.push('/questions')}
function handleLogout(){authStore.logout();userStore.clearProfile();router.replace('/auth')}
onMounted(async()=>{if(authStore.isAuthenticated&&!userStore.profile){try{await userStore.fetchProfile()}catch{}}})
</script>
<style scoped>
.layout-root{min-height:100dvh;padding-left:224px}.sidebar{width:224px;position:fixed;inset:0 auto 0 0;border-right:1px solid var(--line);background:var(--paper-bg);display:flex;flex-direction:column;padding:28px 16px;z-index:40}.brand{display:flex;align-items:center;gap:12px;padding:0 12px 32px}.brand-mark{display:grid;place-items:center;background:var(--primary);color:var(--on-primary);width:36px;height:36px;border-radius:10px;font-size:27px}.brand strong{font-size:20px}.brand small{display:block;font-size:11px;letter-spacing:.12em;color:var(--text-secondary);font-weight:500}.nav-list{display:grid;gap:8px}.nav-item{display:flex;align-items:center;gap:12px;padding:12px 16px;border-radius:10px;color:var(--text-secondary);font-size:14px;min-height:48px}.nav-item .el-icon{font-size:20px}.nav-item.active{background:var(--primary-soft);color:var(--primary);font-weight:600}.nav-item:hover{background:var(--app-bg)}.sidebar-footer{display:flex;align-items:center;gap:8px;margin-top:auto;padding-top:20px;border-top:1px solid var(--line)}.avatar{background:var(--primary-soft);color:var(--primary);width:32px;height:32px;border-radius:50%;display:grid;place-items:center}.user-label{flex:1;overflow:hidden;text-overflow:ellipsis;font-size:14px}.app-toolbar{height:76px;padding:0 32px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--line);background:var(--paper-bg)}.toolbar-leading,.toolbar-right{display:flex;align-items:center;gap:16px}.toolbar-title{font-size:14px;color:var(--text-secondary)}.toolbar-brand{display:none}.connection-status{color:var(--text-secondary);font-size:12px}.connection-status i{display:inline-block;width:6px;height:6px;background:var(--primary);border-radius:50%;margin-right:8px}.content-area{padding:32px;max-width:1680px;margin:auto;min-width:0}.mobile-nav,.mobile-add{display:none}
@media(min-width:768px) and (max-width:1023px){.layout-root{padding-left:80px}.sidebar{width:80px;padding:24px 10px}.brand{padding:0 10px 28px}.brand strong,.nav-item span,.sidebar-footer .user-label,.sidebar-footer .avatar{display:none}.nav-item{padding:14px;justify-content:center}.sidebar-footer{justify-content:center}.content-area{padding:24px}}
@media(max-width:767px){.layout-root{padding-left:0;padding-bottom:calc(160px + env(safe-area-inset-bottom))}.layout-root.immersive{padding-bottom:100px}.sidebar{display:none}.app-toolbar{height:60px;padding:0 16px;position:sticky;top:0;z-index:35}.toolbar-brand{display:block;font-weight:700}.toolbar-title{font-size:13px}.connection-status,.desktop-add{display:none}.content-area{padding:20px 16px}.mobile-nav{display:flex;position:fixed;bottom:0;left:0;right:0;padding:8px 8px calc(8px + env(safe-area-inset-bottom));border-top:1px solid var(--line);background:var(--paper-bg);z-index:40;justify-content:space-around}.mobile-nav a{display:flex;min-width:64px;min-height:48px;gap:4px;flex-direction:column;align-items:center;justify-content:center;color:var(--text-secondary);font-size:12px}.mobile-nav .el-icon{font-size:22px}.mobile-nav a.active{color:var(--primary);font-weight:600}.mobile-add{display:flex}.toolbar-leading{gap:8px}}
</style>
