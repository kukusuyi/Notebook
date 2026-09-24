import { mount, flushPromises } from '@vue/test-utils'
import { expect, it } from 'vitest'
import LatexRenderer from './index.vue'

it('renders OCR inline math and keeps prose', async () => {
  const wrapper = mount(LatexRenderer, {
    props: { content: '当 $x \\to 0$ 时，求 $1-\\cos x$。' },
    global: {
      stubs: {
        ElButton: true,
        ElRadioButton: true,
        ElRadioGroup: true,
      },
    },
  })
  await flushPromises()
  expect(wrapper.findAll('.katex')).toHaveLength(2)
  expect(wrapper.text()).toContain('当')
  expect(wrapper.find('.katex-html').text()).not.toContain('\\cos')
})
