import {ref} from 'vue'
import {httpGet} from '@/api/http'
import {getErrorMessage} from '@/utils/error'
export type UpdateInfo={version:string;current_version:string;description:string;release_url:string;download_url:string;platform:string;arch:string}
const key='questrace:updates:v1'
function preferences(){try{return JSON.parse(localStorage.getItem(key)||'{}')}catch{return {}}}
export const autoUpdate=ref(preferences().enabled!==false),updateInfo=ref<UpdateInfo|null>(null),updateVisible=ref(false),updateBusy=ref(false),updateMessage=ref('')
export function setAutoUpdate(enabled:boolean){autoUpdate.value=enabled;localStorage.setItem(key,JSON.stringify({...preferences(),enabled}))}
export function newerVersion(latest:string,current:string){const parse=(v:string)=>/^v?(\d+)\.(\d+)\.(\d+)(?:\+.*)?$/.exec(v)?.slice(1).map(Number);const a=parse(latest),b=parse(current);if(!a||!b)return false;for(let i=0;i<3;i++){if(a[i]!==b[i])return a[i]>b[i]}return false}
export async function checkUpdate(manual=false){
 if(updateBusy.value||(!manual&&!autoUpdate.value))return
 updateBusy.value=true;updateMessage.value=''
 try{
 const info=await httpGet<UpdateInfo>('/api/v1/updates/latest');updateInfo.value=info
 if(!newerVersion(info.version,info.current_version)){if(manual)updateMessage.value=info.current_version==='dev'?'开发构建，无法比较版本；正式构建会显示实际版本。':'当前已是最新版本';return}
 const prefs=preferences();if(!manual&&prefs.version===info.version&&Date.now()-prefs.reminded<86400000)return
 if(!manual&&!autoUpdate.value)return
 updateVisible.value=true
 localStorage.setItem(key,JSON.stringify({...prefs,version:info.version,reminded:Date.now()}))
 }catch(e){if(manual){const raw=(e as {response?:{data?:{message?:string}}})?.response?.data?.message;updateMessage.value=raw?.startsWith('GitHub 版本查询失败')||raw?.startsWith('无法连接 GitHub')?raw:getErrorMessage(e,'更新检查失败，请稍后重试')}}finally{updateBusy.value=false}
}
