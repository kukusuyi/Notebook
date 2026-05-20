# Math Notebook

Math Notebook 是一个面向数学错题整理、AI 分析、相似题检索和移动复盘的全栈项目。当前仓库已经同时包含：

- `backend/`：Go 后端，负责认证、错题 CRUD、图片上传、OCR、AI 分析、向量检索、移动端版本检查
- `frontend/`：Vue 3 + Vite Web 前端，承担完整业务基线和后台式管理能力
- `mobile/flutter_app/`：Flutter Android 客户端，聚焦拍照上传、OCR 确认、AI 确认、随手复盘
- `deployments/`：部署初始化 SQL 与部署模板
- `docs/`：产品流程、接口设计、架构设计和 Ubuntu 部署文档

## 项目目标

这个项目不是单纯的“题目录入器”，而是一条完整的错题知识闭环：

1. 手动输入错题，或上传题目图片
2. OCR 识别为统一错题 JSON
3. 调用 AI 生成标签、题目语义摘要和错因摘要
4. 写入 MySQL 主库
5. 生成向量并写入 Qdrant
6. 在 Web 和 Android 端查看详情、列表和相似题
7. 通过移动端做碎片化复盘

## 核心能力

### Web 端

- 登录 / 注册
- 仪表盘总览
- 手动新增错题
- 图片上传与 OCR
- AI 分析确认
- 错题列表 / 详情 / 编辑 / 删除
- 相似题检索
- 标签管理
- 系统设置
- 导出打印页

### 后端

- `/api/v1` 统一接口
- JWT 鉴权
- MySQL 数据落库
- MinIO / 腾讯云轻量对象存储 图片存储
- Qdrant 向量检索
- OCR 识别与 AI 分析
- Android 客户端版本检查接口
- OpenAPI 文档页 `/docs`

### Flutter Android 端

- 登录
- 最近错题与快捷入口
- 手动录入
- 拍照 / 相册上传
- OCR 结果确认
- AI 分析确认
- 列表 / 详情 / 相似题
- API 地址覆盖
- APK 更新检测与安装

## 仓库结构

```text
Notebook/
├── backend/
│   ├── cmd/
│   │   ├── api/
│   │   ├── legacydata/
│   │   └── resetdb/
│   ├── configs/
│   ├── internal/
│   ├── prompts/
│   │   ├── chapter_router.md
│   │   └── chapters/
│   ├── scripts/
│   ├── test/
│   ├── go.mod
│   ├── go.sum
│   └── ocr_prompt.md
├── frontend/
│   ├── src/
│   ├── index.html
│   ├── package.json
│   ├── package-lock.json
│   └── vite.config.ts
├── mobile/
│   └── flutter_app/
├── deployments/
│   ├── mysql/
│   ├── nginx/
│   └── systemd/
├── docs/
│   ├── 项目流程文档/
│   ├── 标签系统提示词/
│   ├── 外部工具调用文档/
│   ├── 部署文档/
│   └── ocr_prompt.md
└── README.md
```

## 业务流程

### 方式一：手动录入

```text
用户填写题目 JSON
-> 可选上传原图
-> AI 分析标签 / 摘要
-> 写入 wrong_question
-> 写入标签关系
-> 生成向量
-> 相似题可检索
```

### 方式二：图片识别

```text
上传图片
-> 对象存储保存原图
-> OCR 输出统一 JSON
-> 用户确认 / 编辑
-> 可选手动指定章节；不指定则自动判断章节
-> AI 分析标签 / 摘要
-> 写入 MySQL
-> 写入 Qdrant
-> Web / Android 展示
```

## 运行依赖

建议按下面的版本准备环境：

- Go `1.25.x`
- Node.js `22.x`
- npm `10+`
- MySQL `8.x`
- MinIO 或 OSS对象存储 （虽然做了对S3的兼容，但是没有经过测试）
- Qdrant
- Flutter SDK（Dart `>= 3.4.0`）
- Android Studio / Android SDK（构建 Android APK 时）

## 本地开发快速开始

### 1. 初始化基础依赖

你至少需要先准备：

- MySQL
- MinIO 或腾讯云轻量对象存储（Lighthouse 版）
- Qdrant

MySQL 初始化 SQL 位于：

- [deployments/mysql/mysql.sql](./deployments/mysql/mysql.sql)

后端配置模板位于：

- [backend/configs/config.example.yaml](./backend/configs/config.example.yaml)

### 2. 启动后端

```bash
cd backend
go run ./cmd/api
```

默认监听：

- `http://0.0.0.0:8080`
- OpenAPI 文档：`http://localhost:8080/docs`

### 3. 启动前端

```bash
cd frontend
npm install
npm run dev
```

默认 Web 地址：

- `http://localhost:5173`

前端默认 API 地址来自：

- `frontend/.env.example`
- 浏览器本地存储 `math-notebook:api-base-url`

### 4. 启动 Flutter Android 客户端

```bash
cd mobile/flutter_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## 文档导航

### 部署与交付

- [Ubuntu 部署总览](./docs/部署文档/01-Ubuntu部署总览.md)
- [数据库、对象存储与向量库初始化](./docs/部署文档/02-基础依赖初始化.md)
- [后端部署手册（systemd）](./docs/部署文档/03-后端部署-systemd.md)
- [前端部署手册（Nginx）](./docs/部署文档/04-前端部署-Nginx.md)
- [Flutter Android 构建与发布](./docs/部署文档/05-Flutter-Android构建发布.md)

### 设计与流程

- [项目流程设计](./docs/项目流程文档/02-project-flow-web.md)
- [API 设计文档](./docs/项目流程文档/03-api-design.md)
- [前端页面设计](./docs/项目流程文档/04-frontend_page_design.md)
- [后端模块设计](./docs/项目流程文档/05-backend_module_design.md)
- [Flutter Android 规划](./docs/项目流程文档/06-flutter_android_plan.md)

## 推荐的 Ubuntu 生产部署形态

当前推荐方案如下：

```text
浏览器 / Android
        |
        v
      Nginx
   /         \
Web 静态资源   Go API(systemd)
                  |
                  +--> MySQL
                  +--> MinIO / 腾讯云轻量对象存储
                  +--> Qdrant
                  +--> 外部 OCR / LLM / Embedding 服务
```

适合本项目的原因：

- Web 前端是标准静态产物，最适合由 Nginx 托管
- Go 后端适合编译单二进制并由 systemd 托管
- MySQL、对象存储、Qdrant 职责清晰，便于单独扩容和排障
- Flutter Android 通过同一套 `/api/v1` 契约接入，不需要单独的移动网关

## 当前部署前必须注意的事项

### 1. 后端不是“只拷贝一个二进制就能跑”

当前后端启动时还依赖仓库中的提示词文件：

- `backend/ocr_prompt.md`
- `backend/prompts/chapter_router.md`
- `backend/prompts/chapters/*.md`

部署时如果没把这些文件一起带到服务器，后端会启动失败。

### 2. `CONFIG_PATH` 和 `WorkingDirectory` 必须正确

后端默认从 `configs/config.yaml` 读配置，所以 systemd 里要么：

- 把 `WorkingDirectory` 指向 `backend` 发布目录
- 要么显式设置 `CONFIG_PATH`

### 3. 前端使用 `createWebHistory()`

Nginx 必须配置 SPA 回退规则，否则刷新以下路由会 404：

- `/dashboard`
- `/questions`
- `/questions/:id`
- `/tags`
- `/settings`

### 4. Flutter release 还没有正式签名配置

当前 Android `release` 构建仍是 debug signing，仅适合内部验证。正式发布前必须接入自己的 keystore。

### 5. 移动更新依赖对象存储中的 `apk/` 目录

后端移动版本接口会按照下面的规则拼接下载地址：

```text
provider=oss: {public_base_url}/{bucket}/apk/{apk_filename}
provider=lightcos: {public_base_url}/apk/{apk_filename}
```

所以每次发布 APK 后，都要同步上传到对应对象存储的 `apk/` 目录。

## 部署模板

仓库里已经补了可直接参考的模板：

- [deployments/systemd/math-notebook-backend.service.example](./deployments/systemd/math-notebook-backend.service.example)
- [deployments/systemd/minio.service.example](./deployments/systemd/minio.service.example)
- [deployments/nginx/math-notebook.conf.example](./deployments/nginx/math-notebook.conf.example)

## 验证命令

### 后端测试

```bash
cd backend
go test ./...
```

### 前端构建

```bash
cd frontend
npm run build
```

### Flutter 分析与测试

```bash
cd mobile/flutter_app
flutter analyze
flutter test
```

## 许可证

本项目采用 [Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0)](./LICENSE) 许可。

您可以自由地：

- **分享** — 在任何媒介以任何形式复制、发行本作品
- **演绎** — 修改、转换或以本作品为基础进行创作

惟须遵守下列条件：

- **署名** — 您必须给出适当的署名
- **非商业性使用** — 您不得将本作品用于商业目的
