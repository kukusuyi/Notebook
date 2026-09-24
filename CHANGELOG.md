# 更新日志 / Changelog

## 2.0.0 — 2026-09-23

### 中文

#### 新增

- 本地优先的桌面运行方式，将 Vue 界面、Go 服务、SQLite 数据库和本地文件存储打包在一起。
- Windows x64、macOS Intel 与 Apple Silicon、Linux amd64 与 arm64，以及 Android 发行包。
- 首次启动管理员设置、本地用户管理、备份恢复、外观预设、草稿恢复和双题 A4 导出。
- 由本地管理员配置的可选 OCR、LLM 和 Embedding 服务。

#### 变更

- Notebook 2.0 不再需要 MySQL、MinIO 和 Qdrant。
- 图片、模型设置、题目和向量均保存在 Notebook 本地数据目录。
- 移动客户端连接同一可达网络中的 Notebook 2.0 桌面端或 Linux 服务。

#### 升级说明

- Notebook 2.0 不会自动导入 Notebook 1.x 的数据库或对象存储文件。现有 1.x 安装请继续使用 `master` 或 `dev-ios-adaptation` 分支。
- 替换安装前请备份完整的 Notebook 数据目录；备份包含私人数据和模型凭据。
- 仓库保留 iOS 源码和编译说明，但 v2.0.0 不发布 IPA 或 TestFlight 构建。
- Windows 包使用项目自签名 Authenticode 证书，macOS 包使用未经过 Apple 公证的 ad-hoc 签名；用户首次启动时需要明确允许这些程序运行。

### English

#### Added

- Local-first desktop runtime with the Vue application, Go service, SQLite database and local file storage bundled together.
- Windows x64, macOS Intel and Apple Silicon, Linux amd64 and arm64, and Android release packages.
- First-run administrator setup, local user management, backups and restore, appearance presets, draft recovery, and two-question A4 export.
- Optional OCR, LLM and embedding providers configured by the local administrator.

#### Changed

- MySQL, MinIO and Qdrant are no longer required for Notebook 2.0.
- Images, model settings, questions and vectors are stored in the local Notebook data directory.
- Mobile clients connect to a Notebook 2.0 desktop or Linux service on the same reachable network.

#### Upgrade notes

- Notebook 2.0 does not automatically import Notebook 1.x databases or object-storage files. Continue using the `master` or `dev-ios-adaptation` branch for existing 1.x installations.
- Back up the entire Notebook data directory before replacing an installation. The backup contains private data and model credentials.
- iOS source code remains in the repository, but v2.0.0 does not publish an IPA or TestFlight build.
- Windows packages use a project self-signed Authenticode certificate, and macOS packages use ad-hoc signing without Apple notarization. Users must explicitly trust or allow these packages on first launch.
