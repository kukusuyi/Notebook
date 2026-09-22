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
    <el-button @click="setAppearance(defaults)">恢复默认外观</el-button>
  </section>
</template>
<script setup lang="ts">
import { appearance, defaults, setAppearance, themes, type AppearancePreferences } from '@/theme/appearance'
function setMode(e:Event){setAppearance({mode:(e.target as HTMLSelectElement).value as AppearancePreferences['mode']})}
</script>
<style scoped>
.appearance-panel{padding:24px}.theme-options{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin:20px 0}.theme-option{padding:8px;border:2px solid var(--line);border-radius:12px;color:var(--text-main);background:var(--paper-bg);cursor:pointer}.theme-option[aria-pressed=true]{border-color:var(--primary)}.theme-preview{display:grid;gap:6px;padding:12px;background:var(--preview-bg);border-radius:6px;margin-bottom:8px}.theme-preview i{height:5px;background:var(--preview-line);opacity:.3;border-radius:3px}.theme-preview i:first-child{width:45%;opacity:1}.appearance-row{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin:16px 0}.appearance-row label{min-width:80px}select{background:var(--paper-bg);color:var(--text-main);border:1px solid var(--line);border-radius:8px;padding:10px}input[type=color]{width:48px;height:44px;border:0;padding:4px;background:var(--paper-bg)}
</style>
