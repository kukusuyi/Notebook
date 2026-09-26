// @vitest-environment jsdom
import {mount,flushPromises} from '@vue/test-utils'
import {expect,it,vi} from 'vitest'
import Field from './index.vue'
import {httpPost} from '@/api/http'
vi.mock('@/api/http',()=>({httpPost:vi.fn()}))
it('ignores stale catalog responses after credentials change',async()=>{
 let resolve!:(value:unknown)=>void
 vi.mocked(httpPost).mockImplementation(()=>new Promise(r=>{resolve=r}) as never)
 const wrapper=mount(Field,{props:{kind:'analysis',modelValue:'saved',config:{api_key:'first',base_url:'https://example.com'}},global:{stubs:{ElButton:{template:'<button @click="$emit(\'click\')"><slot/></button>'},ElSelect:true,ElOption:true,ElFormItem:true}}})
 await wrapper.find('button').trigger('click')
 await wrapper.setProps({config:{api_key:'second',base_url:'https://example.com'}})
 resolve({models:['stale']});await flushPromises()
 expect(wrapper.text()).not.toContain('连接成功')
 expect(wrapper.emitted('update:modelValue')).toBeUndefined()
})
