import { mount, flushPromises } from '@vue/test-utils'
import { expect, it, vi } from 'vitest'
import SolutionOCR from './index.vue'
import { recognizeWrongQuestion } from '@/api/ai.api'
vi.mock('@/api/ai.api', () => ({recognizeWrongQuestion: vi.fn().mockResolvedValue({standard_solution:'识别步骤',uncertain_parts:[]})}))
vi.mock('element-plus', () => ({ElMessageBox:{confirm:vi.fn().mockResolvedValue(true)}}))
it('only requests solution OCR and requires explicit application',async()=>{
 const wrapper=mount(SolutionOCR,{props:{modelValue:'原答案'},global:{stubs:{UploadPanel:{template:'<button @click="$emit(\'success\', {image_id:9,image_url:\'/api/v1/files/9\'})">上传测试图</button>'},'el-dialog':{template:'<div><slot/><slot name="footer"/></div>'},'el-button':{template:'<button><slot/></button>'},'el-input':true,'el-alert':true}}})
 const click=async(text:string)=>{const b=wrapper.findAll('button').find(b=>b.text()===text);expect(b).toBeDefined();await b!.trigger('click');await flushPromises()}
 await click('上传测试图');await click('识别答案文字');
 expect(recognizeWrongQuestion).toHaveBeenCalledWith({image_url:'/api/v1/files/9',image_id:9,purpose:'solution'});
 expect(wrapper.emitted('update:modelValue')).toBeUndefined();
 await click('追加到答案');expect(wrapper.emitted('update:modelValue')).toEqual([['原答案\n\n识别步骤']]);
})
