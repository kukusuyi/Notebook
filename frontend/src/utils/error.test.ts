import { expect, it } from 'vitest'
import { getErrorMessage } from './error'
it.each([
  [{ response: { status: 401 } }, '登录'],
  [{ response: { status: 403 } }, '账户'],
  [new Error('Network Error'), '连接失败'],
  [new Error('deadline exceeded'), '超时'],
  [new Error('InvalidApiKey: sk-secret-value'), 'API Key'],
  [new Error('insufficient quota for sk-secret-value'), '额度'],
  [{ response: { status: 429 } }, '限流'],
  [new Error('OCR 服务未配置 API Key'), '未配置'],
  [new Error('InvalidParameter unsupported model'), '模型名称'],
  [new Error('SQL error secret'), '操作未完成'],
])('explains %o safely', (input, expected) => {
  const message = getErrorMessage(input)
  expect(message).toContain(expected)
  expect(message).not.toMatch(/sk-secret|SQL|deadline|InvalidParameter/)
})
it('keeps local validation messages', () => expect(getErrorMessage(new Error('题目内容不能为空'))).toBe('题目内容不能为空'))
