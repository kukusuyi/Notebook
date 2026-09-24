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

开发者需要 Go 1.25+、Node.js 22+；构建 APK 另需 Flutter 3.44.0、JDK 17 与 Android SDK。正式流水线固定这些版本，并在 macOS runner 上执行 Flutter golden 测试，以保证图像基线和发行产物可重复。

```sh
node scripts/build.mjs
cd desktop
npm ci
npm run dist
```

`build.mjs` 不是纯 Node 打包器：它先检查本机是否存在 Go 1.25+，再构建 Vue、嵌入网页并生成独立 Go 程序，最后复制到 Electron 的 resources。第一阶段输出位于 `dist/notebook-2.0.0-<系统>-<架构>/`；随后必须在 `desktop/` 执行 `npm run dist` 才会生成 Windows/macOS 桌面包。可用 `GOOS`/`GOARCH` 选择后端目标；桌面外壳应在对应系统打包。Linux 输出包括 `start.sh`。

若出现 `Go compiler not found`，请先安装 Go 1.25+ 并确认 `go version` 可执行。

移动端：

```sh
cd mobile/flutter_app
printf '{"flavor":"production","apiBaseUrl":""}\n' > config/app_config.json
flutter pub get
flutter build apk --release --dart-define=APP_FLAVOR=production
```

发行构建默认无服务器地址；开发可在设置页填写地址。本地未提供 `android/key.properties` 和 keystore 时仅生成测试包，密钥文件不要提交仓库。

iOS 只能在 macOS + Xcode 环境中构建。无需付费 Apple 开发者账号即可完成无签名 release 编译：

```sh
cd mobile/flutter_app
printf '{"flavor":"production","apiBaseUrl":""}\n' > config/app_config.json
flutter pub get
flutter build ios --release --no-codesign --dart-define=APP_FLAVOR=production
```

上述命令输出 `build/ios/iphoneos/Runner.app`，但无签名应用不能直接安装到 iPhone。模拟器运行无需开发者账号；使用个人 Apple ID 可以通过 Xcode 自动签名安装到自己的 iPhone，但配置描述文件通常只有短期有效期。生成可对外分发的 IPA 或上传 TestFlight/App Store 必须加入 Apple Developer Program。模拟器运行、证书选择、真机调试、归档导出和常见问题见 [iOS 编译说明](mobile/flutter_app/docs/IOS_SETUP.md)。

GitHub Actions 的 `release-v2.yml` 仅允许从 `master-v2.0` 手动预检，或由该分支提交上的 `v2.*` 标签正式发布。它构建 Windows x64、macOS arm64/x64、Linux amd64/arm64 和 Android。Windows 使用项目自签名 Authenticode 证书，macOS 使用 ad-hoc 签名且不进行 Apple 公证，Android 使用项目 release keystore。Windows 和 macOS 包不具备公开 CA/Apple 信任，首次启动会显示安全警告。

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
- `docs/API.md`：2.0 本地服务补充接口说明

1.x 的 MySQL、对象存储和独立服务器部署资料保留在 `master` 与 `dev-ios-adaptation` 分支。2.0 不提供 1.x 数据迁移工具。

## 检查

```sh
cd backend && go test ./...
cd frontend && npm ci && npm run build
cd mobile/flutter_app && flutter analyze && flutter test
```

开发服务端可运行 `go run ./cmd/api --data-dir /tmp/notebook-dev`，开发网页需先构建或单独运行 Vite。接口文档位于 `/docs`。

## 许可证

[CC BY-NC 4.0](LICENSE)：可分享和修改，需署名，禁止商业使用。
