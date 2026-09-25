package openapi

// Local runtime endpoints supplement the unchanged v1 business contract.
func addLocalPaths(paths map[string]any) {
	for path, methods := range map[string][]string{
		"/api/v1/updates/latest":  {"get"},
		"/api/v1/reviews/summary": {"get"}, "/api/v1/reviews/history": {"get"},
		"/api/v1/reviews/sessions": {"post"}, "/api/v1/reviews/sessions/{sessionID}": {"get"}, "/api/v1/reviews/sessions/{sessionID}/results": {"post"},
		"/api/v1/system/status": {"get"}, "/api/v1/system/setup": {"post"},
		"/api/v1/admin/settings": {"get", "put"}, "/api/v1/admin/settings/test": {"post"},
		"/api/v1/admin/users": {"get", "post"}, "/api/v1/vector-jobs": {"get", "post"}, "/api/v1/vector-jobs/retry": {"post"},
		"/api/v1/files/content/{objectKey}": {"get"}, "/api/v1/auth/logout": {"post"},
	} {
		ops := map[string]any{}
		for _, method := range methods {
			op := map[string]any{"tags": []string{"System"}, "summary": path, "responses": map[string]any{"200": map[string]any{"description": "成功，采用统一 code/message/data 响应；文件接口返回图片"}, "400": map[string]any{"description": "参数错误"}, "401": map[string]any{"description": "需要登录"}, "403": map[string]any{"description": "初始化凭据错误或需要管理员权限"}}}
			if path == "/api/v1/updates/latest" || path == "/api/v1/system/status" || path == "/api/v1/system/setup" {
				op["security"] = []any{}
			}
			if method == "post" || method == "put" {
				op["requestBody"] = map[string]any{"content": map[string]any{"application/json": map[string]any{"schema": map[string]any{"type": "object"}}}}
			}
			if path == "/api/v1/reviews/sessions/{sessionID}" || path == "/api/v1/reviews/sessions/{sessionID}/results" {
				op["parameters"] = []any{map[string]any{"name": "sessionID", "in": "path", "required": true, "schema": map[string]any{"type": "integer"}}}
			}
			if path == "/api/v1/files/content/{objectKey}" {
				op["parameters"] = []any{map[string]any{"name": "objectKey", "in": "path", "required": true, "schema": map[string]any{"type": "string"}}}
			}
			ops[method] = op
		}
		paths[path] = ops
	}
}
