# Notebook 2.0 验证记录

验证环境：macOS Apple Silicon；Go 1.25.8、Node.js 22、Electron 41.10.7；Android 构建使用 Temurin JDK 17。以下结果来自本次本地执行，CI 工作流尚未在远端运行。

## 已完成

- `go test -race ./...`：通过。覆盖首次初始化、一次性凭据、管理员权限、用户隔离、图片归属、模型密钥脱敏、无模型 CRUD、事务回滚、标签计数与软删除、持久化向量队列、重试、模型切换及过期任务、备份恢复和新版本数据库拒绝打开。
- Vue 生产构建：通过。浏览器实际完成初始化页面、登录、手动录题、详情和设置页检查。
- Flutter 测试：通过，包含服务器切换后凭据与草稿隔离。`flutter analyze --no-fatal-infos` 通过；仍有 37 条提示级事项（弃用 API、const 与格式建议），无错误或警告。
- Android release APK：构建成功，版本 `2.0.0+20000`，内置服务器地址为空，使用测试签名。
- macOS Apple Silicon Electron 包：打包成功，实际打开独立窗口并显示首次初始化页面。应用未正式签名、公证。
- Windows x64 便携 `.exe`、macOS Intel `.app` 压缩包：交叉打包成功，标记 `unsigned-test`；尚未在相应目标系统上运行。Linux 两种架构均生成二进制与 `start.sh` 压缩包。
- 五个目标的 Go 后端交叉编译：Windows amd64、macOS amd64/arm64、Linux amd64/arm64 全部成功。
- `python3 scripts/smoke.py <本机后端>`：最终 macOS arm64 二进制通过嵌入网页、IPv4 端口占用回退、中文目录、数据目录进程锁、初始化、无模型录题、父进程 stdin EOF 回收、离线备份恢复、JWT 与题目持久化验证。脚本只使用临时目录。

## 容量基准

`NOTEBOOK_CAPACITY_TEST=1 GOMAXPROCS=4 go test ./internal/service -run TestCapacity -v` 在本机测试数据库生成 20 用户、十万题、1024 维向量：20 并发列表请求 P95 约 36 ms；按用户过滤的本地相似检索约 152 ms。Embedding 使用本地模拟响应，不代表外部服务耗时。Go 执行线程限制为 4，本机内存、SSD 和系统并非承诺的目标 Linux 4 核/8 GB 环境，不能将此结果认作 Linux 容量验收。

## 尚需目标设备验收

- Windows、Linux 原生启动、系统防火墙提示和 Linux 4 核/8 GB 容量实测。
- macOS Intel 原生运行；两种桌面系统的托盘交互、重复启动聚焦与异常终止完整 UI 回归。
- Android 真机与电脑局域网上传、拍照、重启后查看、离线提示和打印跨设备闭环。
- 使用实际 OCR、LLM 与 Embedding 凭据的外部模型联调；本地测试覆盖模拟服务及无模型路径。
- 正式桌面签名、公证及正式 Android keystore 签名；无凭据时仅生成明确标注的测试产物。
- 未来增加数据库结构版本时，需要补充对应升级迁移与跨版本恢复测试；2.0 首次 schema 为版本 1，不导入 1.x 数据。

发行工作流包含平台构建矩阵和可运行目标的后端生命周期冒烟。交叉编译、打包成功与目标系统实际运行是不同的验证结果。

工作流对 Intel macOS 使用 `macos-15-intel`，Apple Silicon 使用 `macos-latest`；架构映射参照 [GitHub 托管 Runner 官方说明](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)。
