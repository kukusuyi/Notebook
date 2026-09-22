<template>
  <section class="paper-card appearance-panel">
    <h3>外观</h3><p class="meta-text">选择适合你的阅读空间。设置仅保存在此设备。</p>
    <div class="theme-options">
      <button v-for="(theme,id) in themes" :key="id" class="theme-option" :aria-pressed="appearance.preset===id" @click="setAppearance({preset:id})">
        <span class="theme-preview" :style="{'--preview-bg':theme.light.background,'--preview-line':theme.seed}"><i/><i/><i/></span>{{theme.label}}
      </button>
    </div>
    <div class="appearance-row"><label for="theme-mode">显示模式</label><select id="theme-mode" :value="appearance.mode" @change="setMode"><option value="system">跟随系统</option><option value="light">浅色</option><option value="dark">深色</option></select></div>
    <div class="appearance-row"><label for="theme-color">强调色</label><input id="theme-color" type="color" :value="appearance.accentSeed||themes[appearance.preset].seed" @input="setAppearance({accentSeed:($event.target as HTMLInputElement).value})"/><el-button text @click="setAppearance({accentSeed:null})">使用主题颜色</el-button></div>
    <div class="appearance-row"><label for="theme-material">界面质感</label><select id="theme-material" :value="appearance.material" @change="setAppearance({material:($event.target as HTMLSelectElement).value as AppearancePreferences['material']})"><option value="plain">简洁纸面</option><option value="glass">流光玻璃</option><option value="candy">柔软糖果</option></select></div>
    <p class="meta-text">玻璃让背景轻轻透过导航；糖果用圆润轮廓与柔和高光点缀操作。</p>
    <div class="appearance-row"><label for="theme-font">字体风格</label><select id="theme-font" :value="appearance.font" @change="setAppearance({font:($event.target as HTMLSelectElement).value as AppearancePreferences['font']})"><option value="system">现代黑体</option><option value="rounded">圆润人文</option><option value="serif">书卷宋体</option></select></div>
    <p class="meta-text">使用本机字体；缺少所选字体时自动回退，不需要联网。</p>
    <div class="background-controls"><label class="background-upload">选择背景图片<input type="file" accept="image/jpeg,image/png,image/webp" @change="chooseBackground"/></label><el-button v-if="appearance.background" @click="setAppearance({background:null})">移除背景</el-button></div>
    <p class="meta-text">图片只保存在此浏览器，不会上传到电脑服务。支持 2 MB 以内的 JPG、PNG、WebP。</p>
    <p v-if="backgroundError" class="background-error" role="alert">{{backgroundError}}</p>
    <el-button @click="restore">恢复默认外观</el-button>
  </section>
</template>
<script setup lang="ts">
import { ref } from 'vue'
import { appearance, defaults, setAppearance, themes, type AppearancePreferences } from '@/theme/appearance'
const backgroundError=ref('')
function restore(){backgroundError.value='';setAppearance(defaults)}
async function chooseBackground(e:Event){
 const input=e.target as HTMLInputElement,file=input.files?.[0];if(!file)return
 backgroundError.value=''
 if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>2*1024*1024){backgroundError.value='请选择 2 MB 以内的 JPG、PNG 或 WebP 图片。';input.value='';return}
 try{
 const data=await new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result));reader.onerror=reject;reader.readAsDataURL(file)})
 await new Promise<void>((resolve,reject)=>{const image=new Image();image.onload=()=>resolve();image.onerror=reject;image.src=data})
 localStorage.setItem('notebook:appearance:v1',JSON.stringify({...appearance,background:data}))
 setAppearance({background:data})
 }catch{backgroundError.value='图片无法读取或本机存储空间不足，请换一张较小的图片。'}finally{input.value=''}
}
function setMode(e:Event){setAppearance({mode:(e.target as HTMLSelectElement).value as AppearancePreferences['mode']})}
</script>
<style scoped>
.appearance-panel{padding:24px}.theme-options{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin:20px 0}.theme-option{padding:8px;border:2px solid var(--line);border-radius:12px;color:var(--text-main);background:var(--paper-bg);cursor:pointer}.theme-option[aria-pressed=true]{border-color:var(--primary)}.theme-preview{display:grid;gap:6px;padding:12px;background:var(--preview-bg);border-radius:6px;margin-bottom:8px}.theme-preview i{height:5px;background:var(--preview-line);opacity:.3;border-radius:3px}.theme-preview i:first-child{width:45%;opacity:1}.appearance-row{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin:16px 0}.appearance-row label{min-width:80px}select{background:var(--paper-bg);color:var(--text-main);border:1px solid var(--line);border-radius:8px;padding:10px}input[type=color]{width:48px;height:44px;border:0;padding:4px;background:var(--paper-bg)}
.background-controls{display:flex;flex-wrap:wrap;gap:12px}.background-upload{display:inline-flex;align-items:center;min-height:44px;padding:0 16px;border:1px solid var(--line);border-radius:10px;cursor:pointer}.background-upload input{max-width:200px;margin-left:12px}.background-error{color:var(--el-color-danger)}
</style>
