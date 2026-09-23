package errors

import "strings"

// ProviderMessage returns actionable, credential-free diagnostics for model failures.
func ProviderMessage(status int, raw string) string {
	s := strings.ToLower(raw)
	has := func(words ...string) bool {
		for _, word := range words {
			if strings.Contains(s, word) {
				return true
			}
		}
		return false
	}
	switch {
	case status == 402 || has("quota", "insufficient", "balance", "arrear", "额度", "欠费"):
		return "模型服务额度不足或账户欠费，请在服务商控制台检查余额和计费状态。"
	case status == 401 || has("invalid_api_key", "invalid api key", "invalidapikey", "incorrect api key", "authentication", "key 无效"):
		return "模型 API Key 无效，请检查密钥是否正确、已启用且属于当前地域。"
	case status == 403 || has("accessdenied", "access denied", "forbidden", "permission", "权限不足"):
		return "模型服务权限不足，请检查服务开通状态、模型授权和 API Key 所属地域。"
	case status == 429 || has("rate limit", "ratelimit", "throttl", "限流"):
		return "模型服务触发限流，请稍等片刻后重试。"
	case has("timeout", "deadline", "timed out", "超时"):
		return "模型服务响应超时，请检查电脑的互联网连接后重试。"
	case has("no such host", "connection", "network", "dial tcp", "socket", "无法连接"):
		return "电脑无法连接模型服务，请检查互联网连接、服务地址与代理设置。"
	case status == 404 || has("modelnotfound", "model not", "invalidparameter", "does not support", "unsupported", "不受支持"):
		return "模型名称或请求参数不受支持，请检查模型名称；图片识别需要支持视觉输入的模型。"
	case has("decode", "unmarshal", "json", "no choices", "empty", "格式异常"):
		return "模型返回格式异常，请重试或更换兼容模型。"
	default:
		return "模型服务暂时无法完成请求，请稍后重试；若持续发生，请检查模型配置。"
	}
}
