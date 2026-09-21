# 题迹 Notebook 2.0

题迹是一款错题整理、图片录入、AI 分析与相似题复盘工具。2.0 将服务端和网页打包到电脑程序中：数据留在电脑，手机连接电脑使用。

## 下载与使用

- **Windows**：下载对应的便携 `.exe`，运行后打开独立窗口；关闭窗口进入托盘，托盘菜单可退出服务。
- **macOS**：解压对应芯片的 `.app` 并打开。关闭窗口进入菜单栏，退出会停止服务。
- **Linux**：解压对应架构的发行包，运行 `./start.sh`，浏览器打开输出的地址。
- **Android**：安装 APK，填写电脑显示的局域网地址（例如 `http://192.168.1.10:8080`），验证连接后登录。

无需安装或配置 MySQL、MinIO、Qdrant、Docker、Node.js 或 Go。电脑需保持运行，手机与电脑需网络互通；系统提示防火墙授权时允许局域网访问。不同平台需要下载各自的发行包。

首次运行时创建管理员。桌面窗口自动带入初始化凭据；Linux 用户从启动输出复制 `setup_token`。公开注册默认关闭，管理员可在设置中添加用户或开启注册。

**没有模型密钥也可以手动录题、上传图片、管理标签、查询和打印。** 管理员在设置页添加 AI 模型服务后可使用分析；OCR 当前使用通义千问视觉模型；相似题需要配置兼容 OpenAI Embeddings 接口的模型。模型调用需要联网并由服务商计费。密钥保存在电脑的数据目录，不分发给手机。

## 数据与备份

默认数据目录：

| 平台 | 位置 |
|---|---|
| Windows | `%APPDATA%\Notebook` |
| macOS | `~/Library/Application Support/Notebook` |
| Linux | `$XDG_DATA_HOME/Notebook`，未设置时为 `~/.local/share/Notebook` |

目录包含 `notebook.db`、`files/`、`settings.json`、`notebook.log`。重装或替换程序不会覆盖数据。备份含模型密钥与登录配置，应作为私人文件保存。

退出程序后执行（Windows 使用发行产物中的维护二进制 `notebook-server.exe`；macOS 可使用 `.app/Contents/Resources/backend/notebook-server`）：

```sh
./notebook-server --backup /path/outside-data/notebook-backup.zip
./notebook-server --restore /path/notebook-backup.zip
```

可加 `--data-dir /path/to/data` 指定目录。恢复先验证临时目录，成功后替换；恢复前数据保留在同级 `*.before-restore-*` 目录。数据目录加进程锁，不允许多个进程同时运行或在线恢复。首次 2.0 建库不导入 1.x 数据。

默认端口为 8080，被占用时自动选择空闲端口；`--port 8090` 显式指定时，冲突会报错。`--host 127.0.0.1` 可限制为本机使用。公网 HTTPS、自动更新和跨电脑同步不在 2.0 首版范围内。

## 源码构建

开发者需要 Go 1.25+、Node.js 22+；构建 APK 另需 Flutter 与 Android SDK。

```sh
node scripts/build.mjs
cd desktop
npm ci
NOTEBOOK_RELEASE_KIND=unsigned-test npm run dist
```

`build.mjs` 先构建 Vue，再嵌入网页、提示词、数据库初始化 SQL，生成独立 Go 程序，并复制到 Electron 的 resources。输出位于 `dist/`。可用 `GOOS`/`GOARCH` 选择后端目标；桌面外壳应在对应系统打包。Linux 输出包括 `start.sh`。

移动端：

```sh
cd mobile/flutter_app
printf '{"flavor":"production","apiBaseUrl":""}\n' > config/app_config.json
flutter pub get
flutter build apk --release --dart-define=APP_FLAVOR=production
```

发行构建默认无服务器地址；开发可在设置页填写地址。提供 `android/key.properties` 和 keystore 时使用正式 Android 签名，否则使用 debug 签名，仅供测试。密钥文件不要提交仓库。

GitHub Actions 的 `release-v2.yml` 构建 Windows x64、macOS arm64/x64、Linux amd64/arm64 和 Android。工作流上传构建产物，不自动公开发布。未提供桌面签名证书时产物标记 `unsigned-test`；macOS 公证另需 Apple 凭据。未签名程序可能触发操作系统提示。

## 架构

```text
Electron 窗口 / 浏览器 / Flutter APK
                 │ HTTP /api/v1
                 ▼
       Go 单进程服务（含 Vue 网页与提示词）
          ├── SQLite：账户、题目、标签、向量与任务队列
          ├── 本地 files/：鉴权图片
          └── 可选外部 OCR / LLM / Embedding API
```

保留登录与用户数据隔离。向量生成是持久化后台任务：题目保存不等待模型；失败可重试；更换模型会排队重建。检索先过滤用户、科目和标签，再计算相似度，避免跨用户候选截断。

- `backend/`：本地后端、API、存储与任务
- `frontend/`：桌面窗口和浏览器共享的 Vue 页面
- `desktop/`：Electron 生命周期、托盘和打包
- `mobile/flutter_app/`：Android/iOS 客户端源码
- `scripts/`：发行构建入口
- `docs/v2/`：2.0 接口与验证记录

`deployments/` 和原部署文档属于 1.x 历史资料，不适用于 2.0。旧 MySQL/对象存储数据继续使用旧版本，2.0 不提供迁移工具。

## 检查

```sh
cd backend && go test ./...
cd frontend && npm ci && npm run build
cd mobile/flutter_app && flutter analyze --no-fatal-infos && flutter test
```

开发服务端可运行 `go run ./cmd/api --data-dir /tmp/notebook-dev`，开发网页需先构建或单独运行 Vite。接口文档位于 `/docs`。

## 许可证

[CC BY-NC 4.0](LICENSE)：可分享和修改，需署名，禁止商业使用。
