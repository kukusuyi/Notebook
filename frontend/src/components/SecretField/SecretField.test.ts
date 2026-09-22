import { mount } from '@vue/test-utils'
import { expect, it, vi } from 'vitest'
import SecretField from './index.vue'
vi.mock('element-plus',()=>({ElMessageBox:{confirm:vi.fn().mockResolvedValue(true)}}))
it('shows configured status without exposing the protocol sentinel',async()=>{
 const wrapper=mount(SecretField,{props:{modelValue:'__KEEP__'},global:{stubs:{'el-button':{template:'<button><slot/></button>'},'el-input':{template:'<input/>'}}}})
 expect(wrapper.text()).toContain('已配置');expect(wrapper.html()).not.toContain('__KEEP__');
 await wrapper.findAll('button')[0].trigger('click');expect(wrapper.emitted('update:modelValue')).toEqual([['']]);
})
