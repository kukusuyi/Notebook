// @vitest-environment jsdom
import {beforeEach,describe,expect,it,vi} from 'vitest'
vi.mock('@/api/http',()=>({httpGet:vi.fn()}))
import {httpGet} from '@/api/http'
import {autoUpdate,checkUpdate,newerVersion,updateInfo,updateMessage,updateVisible,setAutoUpdate} from './updates'
const info={version:'2.1.0',current_version:'2.0.0',description:'更新',release_url:'https://github.com/kukusuyi/Questrace/releases/tag/v2.1.0',download_url:'',platform:'ios',arch:''}
beforeEach(()=>{localStorage.clear();autoUpdate.value=true;updateVisible.value=false;updateInfo.value=null;vi.mocked(httpGet).mockReset()})
describe('updates',()=>{
 it('compares numeric versions without downgrades',()=>{expect(newerVersion('2.10.0','2.9.0')).toBe(true);expect(newerVersion('2.0.0','2.0.0')).toBe(false);expect(newerVersion('v2.1.0','2.0.0+20000')).toBe(true);expect(newerVersion('2.1.0','dev')).toBe(false)})
 it('honors disabled automatic checks but allows manual checks',async()=>{setAutoUpdate(false);vi.mocked(httpGet).mockResolvedValue(info);await checkUpdate();expect(httpGet).not.toHaveBeenCalled();await checkUpdate(true);expect(updateVisible.value).toBe(true)})
 it('reminds once a day and leaves manual errors visible',async()=>{vi.mocked(httpGet).mockResolvedValue(info);await checkUpdate();expect(updateVisible.value).toBe(true);updateVisible.value=false;await checkUpdate();expect(updateVisible.value).toBe(false);await checkUpdate(true);expect(updateVisible.value).toBe(true);vi.mocked(httpGet).mockRejectedValue(new Error('无法连接 GitHub，请稍后重试'));await checkUpdate(true);expect(updateMessage.value).toContain('无法连接 GitHub')})
})
