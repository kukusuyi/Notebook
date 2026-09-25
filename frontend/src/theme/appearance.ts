import {storeBackground,loadBackground,validateBackground} from './background'
import { argbFromHex, hexFromArgb, TonalPalette } from '@material/material-color-utilities'
import { reactive } from 'vue'
import themes from '../../../design-system/questrace/themes.json'
export { themes }
export type Preset = keyof typeof themes
export type AppearancePreferences = {version:1; preset:Preset; mode:'system'|'light'|'dark'; accentSeed:string|null; material:'plain'|'glass'|'candy'; font:'system'|'rounded'|'serif'; background:string|null}
export const appearanceKey = 'questrace:appearance:v1'
export const defaults:AppearancePreferences = {version:1,preset:'blue',mode:'system',accentSeed:null,material:'plain',font:'system',background:null}
export function normalizeAppearance(value: unknown): AppearancePreferences {
  const p = (value && typeof value==='object' ? value : {}) as Partial<AppearancePreferences>
  return {material:['plain','glass','candy'].includes(p.material||'')?p.material!:'plain',font:['system','rounded','serif'].includes(p.font||'')?p.font!:'system',background:typeof p.background==='string' && (p.background==='idb:background'||/^data:image\/(jpeg|png|webp);base64,[a-zA-Z0-9+/=]+$/.test(p.background) && p.background.length<14000050)?p.background:null,version:1,preset:p.preset && p.preset in themes?p.preset:'blue',mode:['system','light','dark'].includes(p.mode||'')?p.mode!:'system',accentSeed:/^#[\da-f]{6}$/i.test(p.accentSeed||'')?p.accentSeed!:null}
}
let stored:unknown
try { stored=JSON.parse(localStorage.getItem(appearanceKey)||'null') } catch { stored=null }
export const appearance = reactive(normalizeAppearance(stored))
export function paletteFor(p:AppearancePreferences,dark:boolean) {
  const theme=themes[p.preset], colors=dark?theme.dark:theme.light
  const palette=TonalPalette.fromInt(argbFromHex(p.accentSeed||theme.seed))
  const tone=(n:number)=>hexFromArgb(palette.tone(n))
  return {...colors,primary:tone(dark?80:40),onPrimary:tone(dark?20:100),soft:tone(dark?25:95),borderPrimary:tone(dark?60:60)}
}
let backgroundURL:string|null=null
export async function refreshBackground(){
 const blob=await loadBackground();if(backgroundURL)URL.revokeObjectURL(backgroundURL);backgroundURL=blob?URL.createObjectURL(blob):null;applyAppearance()
}
export async function saveBackground(blob:Blob|null){if(blob)validateBackground(blob);await storeBackground(blob);setAppearance({background:blob?'idb:background':null});await refreshBackground()}
export function applyAppearance() {
  const dark=appearance.mode==='dark'||(appearance.mode==='system'&&matchMedia('(prefers-color-scheme: dark)').matches)
  const c=paletteFor(appearance,dark), root=document.documentElement
  root.dataset.material=appearance.material;root.dataset.font=appearance.font;root.classList.toggle('has-background',Boolean(appearance.background));const url=appearance.background==='idb:background'?backgroundURL:appearance.background;root.style.setProperty('--user-background',url?`url("${url}")`:'none');
  root.classList.toggle('dark',dark);root.dataset.theme=appearance.preset;root.style.colorScheme=dark?'dark':'light'
  const tokens:Record<string,string>={'app-bg':c.background,'paper-bg':c.surface,'paper-strong':c.surface,'text-main':c.text,'text-secondary':c.muted,'line':c.border,'line-strong':c.border,'primary':c.primary,'primary-soft':c.soft,'on-primary':c.onPrimary,'accent':c.primary,'accent-soft':c.soft,'shadow':'0 2px 8px rgb(0 0 0 / 0.03)','danger-soft':dark?'#522529':'#FDEBEC','el-color-primary':c.primary,'el-color-primary-dark-2':c.primary,'el-color-primary-light-3':c.borderPrimary,'el-color-primary-light-5':c.borderPrimary,'el-color-primary-light-7':c.soft,'el-color-primary-light-8':c.soft,'el-color-primary-light-9':c.soft,'el-bg-color':c.surface,'el-bg-color-page':c.background,'el-bg-color-overlay':c.surface,'el-fill-color-blank':c.surface,'el-fill-color':c.background,'el-fill-color-light':c.background,'el-fill-color-lighter':c.background,'el-fill-color-extra-light':c.background,'el-text-color-primary':c.text,'el-text-color-regular':c.text,'el-text-color-secondary':c.muted,'el-text-color-placeholder':c.muted,'el-border-color':c.border,'el-border-color-light':c.border,'el-border-color-lighter':c.border,'el-mask-color':dark?'rgb(17 21 29 / .8)':'rgb(255 255 255 / .8)'}
  for(const [k,v] of Object.entries(tokens))root.style.setProperty('--'+k,v)
}
export function setAppearance(update:Partial<AppearancePreferences>) {
  Object.assign(appearance,normalizeAppearance({...appearance,...update}))
  try{localStorage.setItem(appearanceKey,JSON.stringify(appearance))}catch{/* private browsing still supports current-session themes */}
  applyAppearance()
}
export function initAppearance(){applyAppearance();
 void (async()=>{try{if(appearance.background?.startsWith('data:')){const blob=await (await fetch(appearance.background)).blob();await saveBackground(blob)}else if(appearance.background==='idb:background')await refreshBackground()}catch{/* Keep legacy image if migration fails. */}})();matchMedia('(prefers-color-scheme: dark)').addEventListener('change',applyAppearance);window.addEventListener('storage',e=>{if(e.key===appearanceKey){try{Object.assign(appearance,normalizeAppearance(JSON.parse(e.newValue||'null')));void refreshBackground().catch(()=>{});applyAppearance()}catch{}}})}
