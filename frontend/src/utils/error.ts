/** Translate transport/provider diagnostics without exposing upstream bodies or credentials. */
export function getErrorMessage(error: unknown, fallback = '操作未完成，请稍后重试。'): string {
  const e=error as {message?:string;code?:string|number;status?:number;response?:{status?:number;data?:{message?:string}}}|null
  const text=String(e?.response?.data?.message||e?.message||'')
  const status=e?.response?.status||e?.status
  if(/insufficient|quota|arrear|balance|payment|额度|欠费|余额/i.test(text)||status===402)return '模型服务额度不足或账户欠费，请在服务商控制台检查余额、免费额度和计费状态。'
  if(/invalid.?api.?key|incorrect.?api.?key|authenticationerror|api.?key.*(invalid|未配置|无效)|密钥无效/i.test(text))return /未配置/.test(text)?'尚未配置模型密钥，请管理员在“设置 → 模型服务”填写 API Key。':'模型服务拒绝了 API Key，请管理员检查密钥是否正确、已启用且属于当前地域。'
  if(/rate.?limit|too many|throttl|限流/i.test(text)||status===429)return '模型服务请求过于频繁，触发限流。请稍等片刻再试。'
  if(/model.*(not.found|not.exist|invalid|not.support)|模型.*(不存在|不支持|不受支持)|does not support|invalidparameter/i.test(text))return '模型名称或请求参数不受支持，请检查模型名称，并为图片识别选择支持视觉输入的模型。'
  if(/access.?denied|permission.?denied|forbidden|not.authorized|权限不足/i.test(text))return '模型服务权限不足，请检查服务是否已开通、模型授权和 API Key 所属地域。'
  if(/timeout|timed.out|deadline|超时/i.test(text)||e?.code==='ECONNABORTED')return '请求超时。请检查电脑网络或模型服务状态后重试，已填写的内容会保留。'
  if(/电脑无法连接模型服务/.test(text))return '电脑无法连接模型服务，请检查电脑的互联网连接、服务地址和代理设置。'
  if(/network error|failed to fetch|econn|socket|dns|no such host|connection|网络|连接失败/i.test(text))return '连接失败。请确认电脑端正在运行、手机与电脑处于同一网络，并检查服务器地址、防火墙及电脑的互联网连接。'
  if(status===401)return '登录已过期或账号密码不正确，请重新登录。'
  if(status===403)return '当前账户没有执行此操作的权限，请联系管理员。'
  if(status===413)return '图片过大，请裁剪图片或选择体积更小的文件。'
  if(/未配置|尚未配置/.test(text))return '此功能尚未配置模型服务，请管理员在“设置 → 模型服务”完成配置；仍可手动整理和保存错题。'
  if(/decode|invalid json|unexpected token|no choices|非 JSON|格式异常/i.test(text))return '模型返回了无法识别的内容，请重试或更换兼容模型，也可以手动填写。'
  if(status===404)return '内容不存在或已被删除，请刷新页面后重试。'
  if(status && status>=500)return '电脑端或模型服务暂时无法完成请求，请稍后重试；若持续发生，请检查模型配置。'
  // Preserve concise application validation messages, never raw diagnostics/URLs.
  if(/[\u4e00-\u9fff]/.test(text)&&text.length<180&&!/error|exception|https?:|sql|stack|sk-[a-z0-9]|\{\s*"/i.test(text))return text
  return fallback
}
