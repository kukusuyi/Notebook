// @vitest-environment jsdom
import {mount,flushPromises} from '@vue/test-utils'
import {createPinia} from 'pinia'
import {expect,it,vi} from 'vitest'
import Selector from './index.vue'
import {listAIModelProviders,listAIProviderModels} from '@/api/ai.api'
vi.mock('@/api/ai.api',()=>({listAIModelProviders:vi.fn(),listAIProviderModels:vi.fn()}))
it('uses configured model without requesting provider catalog',async()=>{
 vi.mocked(listAIModelProviders).mockResolvedValue({list:[{provider_name:'qwen',provider_type:'qwen',configured_model:'qwen3.8-flash'}]})
 const wrapper=mount(Selector,{props:{providerName:'qwen',modelName:'old-model'},global:{plugins:[createPinia()],stubs:{ElFormItem:true,ElSelect:true,ElOption:true,ElButton:true}}})
 await flushPromises()
 expect(wrapper.emitted('update:modelName')?.at(-1)).toEqual(['qwen3.8-flash'])
 expect(listAIProviderModels).not.toHaveBeenCalled()
 expect(wrapper.text()).toContain('32B')
})
