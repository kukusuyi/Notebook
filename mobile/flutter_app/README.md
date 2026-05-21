# Flutter Mobile Client

这个目录用于承载错题本项目的 Flutter 移动端客户端，当前以 Android 与 iOS 双端为目标。

当前已落地：

- `lib/` 下的应用骨架、路由、主题、网络层、共享模型
- 登录、手动录入、图片上传、OCR 确认、AI 确认、列表、详情、相似题、设置页面壳子
- 基于 `shared_preferences` 的本地草稿恢复与 API Base URL 覆盖

本机准备好 Flutter 与 Xcode 后，建议在本目录执行：

```bash
cp config/app_config.example.json config/app_config.json
flutter create . --platforms=ios --project-name math_notebook_flutter --org com.mathnotebook
flutter pub get
flutter run
```

移动端默认 API 地址优先读取：

- `config/app_config.json`
- 如果设置页手动覆盖，则优先使用覆盖值
- 如果 `app_config.json` 不存在或为空，则回退到 `dart-define` / 内置默认值

推荐流程：

1. 复制 [app_config.example.json](./config/app_config.example.json) 为本地 `config/app_config.json`
2. 把 `apiBaseUrl` 改成当前环境地址
3. 再执行 `flutter run` / `flutter build`

说明：

- `config/app_config.json` 已加入仓库根 `.gitignore`，不会被提交
- 正式包构建前一定要检查这个文件里的 `apiBaseUrl`
- Android 模拟器开发默认可用 `http://10.0.2.2:8080`

iOS / Android 适配要点：

- 正式应用包名沿用 `com.mathnotebook.mobile`
- Android 侧已补充 `INTERNET` 与安装更新相关权限
- iOS 侧需要通过 `flutter create . --platforms=ios` 生成原生工程后，再执行 `flutter pub get`
- 原生配置补充项见 [docs/IOS_SETUP.md](./docs/IOS_SETUP.md)
- 开发阶段默认地址会按设备类型选择：
  - Android 模拟器：`http://10.0.2.2:8080`
  - iOS 模拟器：`http://127.0.0.1:8080`
  - 真机：请在 `config/app_config.json` 或设置页填写宿主机局域网地址
