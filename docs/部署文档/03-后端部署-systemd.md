# 后端部署（systemd）

本文档说明如何把 Go 后端部署到 Ubuntu，并通过 `systemd` 管理。

## 1. 后端职责

后端入口位于：

- [backend/cmd/api/main.go](../../backend/cmd/api/main.go)

默认暴露的关键接口包括：

- `GET /healthz`
- `GET /docs`
- `GET /docs/openapi.json`
- `/api/v1/auth/*`
- `/api/v1/files/images`
- `/api/v1/ocr/wrong-question-json`
- `/api/v1/ai/*`
- `/api/v1/wrong-questions/*`
- `/api/v1/mobile/latest-version`

## 2. 编译发布包

在构建机或服务器上执行：
powershell:

```bash
cd backend
go test ./...
$env:GOOS="linux"; $env:GOARCH="amd64"; go build -o math-notebook-backend ./cmd/api
```

发布时不要只上传二进制，还要一起带上这些文件：

- `configs/config.yaml`
- `ocr_prompt.md`
- `prompts/chapter_router.md`
- `prompts/chapters/`

推荐发布目录：

```text
/opt/math-notebook/backend/
├── math-notebook-backend
├── configs/
│   └── config.yaml
├── prompts/
│   ├── chapter_router.md
│   └── chapters/
│       └── 函数的极限和连续.md
└── ocr_prompt.md
```

## 3. 生产配置文件

建议从模板复制：

```bash
cp backend/configs/config.example.yaml /opt/math-notebook/backend/configs/config.yaml
```

然后至少修改以下内容：

### app

```yaml
app:
  host: 127.0.0.1
  port: 8080
  env: production
```

建议后端只监听本机 `127.0.0.1`，由 Nginx 做统一入口。

### auth / jwt

```yaml
auth:
  enable_registration: false

jwt:
  secret: "replace-with-very-strong-secret"
  expiration_hours: 168
```

### db

```yaml
db:
  host: 127.0.0.1
  port: 3306
  user: mathnotebook
  password: "replace-with-strong-password"
  name: wrong_question_book
```

### file / 对象存储

```yaml
file:
  provider: oss
  bucket: wrong-question-images
  base_url: https://files.example.com
  minio:
    endpoint: 127.0.0.1:9000
    access_key: admin
    secret_key: "replace-with-strong-password"
    use_ssl: false
    public_base_url: https://files.example.com
    auto_create_bucket: false
    public_read: false
```

如果你使用腾讯云轻量对象存储（Lighthouse 版），建议改为：

```yaml
file:
  provider: lightcos
  bucket: examplebucket-1250000000
  base_url: https://files.example.com
  lightcos:
    bucket_url: https://examplebucket-1250000000.light-cos.com
    secret_id: "your-secret-id"
    secret_key: "your-secret-key"
    public_base_url: https://files.example.com
```

### vector / qdrant

```yaml
vector:
  collection_name: wrong_question_vectors
  qdrant_url: http://127.0.0.1:6333
  api_key: ""
  distance: Cosine
  timeout_seconds: 30
```

### imageOcr / models / embedding_model

把所有占位 API Key 替换成真实值：

- `imageOcr.api_key`
- `models[*].api_key`
- `embedding_model.api_key`

### mobile_version

移动更新接口依赖：

```yaml
mobile_version:
  version: "1.0.0"
  apk_filename: "math-notebook.apk"
  force_update: false
  update_description: "修复已知问题"
```

注意：

- `provider: oss` 时，`apk_filename` 必须和 `{bucket}/apk/` 目录中的文件名一致
- `provider: lightcos` 时，`apk_filename` 必须和 `apk/` 目录中的文件名一致
- 后端会自动把它拼成下载 URL

## 4. systemd 服务文件

仓库模板：

- [deployments/systemd/math-notebook-backend.service.example](../../deployments/systemd/math-notebook-backend.service.example)

复制：

```bash
sudo cp deployments/systemd/math-notebook-backend.service.example /etc/systemd/system/math-notebook-backend.service
```
然后根据服务器上实际存放目录更改
## 5. 启动服务（注意启动服务前要先确保mysql已经完成建表）

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now math-notebook-backend
sudo systemctl status math-notebook-backend
```

查看日志：

```bash
sudo journalctl -u math-notebook-backend -f
```

## 6. 启动后验证

### 本机健康检查

```bash
curl http://127.0.0.1:8080/healthz
```

期望返回：

```text
ok
```

### OpenAPI 文档

```bash
curl http://127.0.0.1:8080/docs/openapi.json
```

### 常见启动失败原因

#### 1. 配置文件路径不对

表现：

- 服务启动即退出
- 日志里出现数据库、对象存储、Qdrant 等默认地址连接失败

原因：

- 当前后端默认读取 `configs/config.yaml`
- 如果 `WorkingDirectory` 不正确，就可能读不到配置

建议：

- 在 systemd 里设置正确的 `WorkingDirectory`
- 或者显式加 `Environment=CONFIG_PATH=...`

#### 2. 提示词文件未带上

表现：

- OCR / AI 服务初始化失败

原因：

- 当前实现会在启动时读取：
  - `ocr_prompt.md`
  - `prompts/chapter_router.md`
  - `prompts/chapters/*.md`

#### 3. 对象存储配置不完整

表现：

- 服务在文件存储初始化时报错

建议：

- 使用 MinIO 时，生产环境提前手动创建 bucket，并配置 `auto_create_bucket: false`
- 使用腾讯云轻量对象存储时，提前在控制台创建 bucket，并填写正确的 `lightcos.bucket_url`、`secret_id`、`secret_key`

#### 4. MySQL 用户权限不足

表现：

- 默认用户初始化失败
- 表读写失败

#### 5. 外部 AI Key 未配置

表现：

- OCR 或 AI 分析接口返回失败

## 7. 升级发布建议

建议每次升级按这个顺序：

1. 备份 `config.yaml`
2. 上传新二进制
3. 如果有文档依赖变更，同步上传提示词文件
4. 执行 `sudo systemctl restart math-notebook-backend`
5. 检查 `/healthz`
6. 检查 `/docs`
7. 跑一遍上传、OCR、AI 分析、保存、相似题主流程

## 8. 相关模板

- [deployments/systemd/math-notebook-backend.service.example](../../deployments/systemd/math-notebook-backend.service.example)
- [deployments/nginx/math-notebook.conf.example](../../deployments/nginx/math-notebook.conf.example)
