# 2.0 本地服务 API

业务接口沿用 `/api/v1`，JSON 响应为 `{code,message,data}`。登录返回 Bearer Token 并设置同源 HttpOnly Cookie；移动端使用 Bearer，网页图片读取使用 Cookie。网页请求需同源。普通用户只能访问自己的题目、图片、导出和向量任务。

| 接口 | 权限 | 说明 |
|---|---|---|
| GET `/api/v1/system/status` | 公开 | version、setup_required、registration_enabled、ocr_enabled、ai_enabled、embedding_enabled、urls |
| POST `/api/v1/system/setup` | 一次性凭据 | `{token,username,email,password}`；创建唯一初始管理员 |
| GET/PUT `/api/v1/admin/settings` | 管理员 | 读取脱敏设置或保存设置，保存后生效 |
| POST `/api/v1/admin/settings/test` | 管理员 | 同设置请求体；测试 LLM 模型列表与 Embedding 请求，不保存 |
| GET/POST `/api/v1/admin/users` | 管理员 | 列出用户；以 `{username,email,password}` 创建普通用户 |
| GET `/api/v1/vector-jobs` | 登录 | 当前用户 pending/done/failed 数量 |
| POST `/api/v1/vector-jobs` | 登录 | 重新调度当前用户未完成任务 |
| GET `/api/v1/files/content/{objectKey}` | 文件所有者 | 图片二进制，objectKey 为上传响应中的服务端路径 |
| POST `/api/v1/auth/logout` | 同源 | 清除浏览器会话 Cookie；客户端仍需清除本地 Token |

设置示例：

```json
{
  "registration_enabled": false,
  "ocr": {"name":"qwen","model":"qwen3.6-plus","api_key":""},
  "models": [{"name":"example","provider_type":"openai_compatible","base_url":"https://example.com/v1","model":"example-model","api_key":"your-key"}],
  "embedding": {"provider_type":"openai_compatible","base_url":"https://example.com/v1","model":"embedding-model","api_key":""},
  "download_url":""
}
```

读取设置时已有密钥显示 `__KEEP__`；回传此值保留密钥。清空 OCR/Embedding 密钥会停用对应功能；移除 models 项会停用对应 LLM 服务。模型服务密钥不能从读取接口取回。更换 Embedding 模型/服务地址会重新调度向量，旧模型向量不会参与新模型搜索。

创建或更新题目不再要求 AI 语义摘要；`source_image_id` 必须归当前用户，图片路径由服务器取回，不信任调用方填写的 URL。未配置 Embedding 时相似题接口返回 503；普通 CRUD 不受影响。

发行版本 `2.0.0` 不代表 API 路径必须改为 `/api/v2`。现有题目接口契约尽量保留，但 2.0 客户端应连接 2.0 后端。

移动端也可使用 `POST /api/v1/vector-jobs/retry`，与 `POST /api/v1/vector-jobs` 相同：重试当前用户尚未完成的任务。
