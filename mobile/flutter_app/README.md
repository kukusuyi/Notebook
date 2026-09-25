# Flutter Mobile Client

这个目录用于承载错题本项目的 Flutter 移动端客户端，当前以 Android 与 iOS 双端为目标。

当前已落地：

- `lib/` 下的应用骨架、路由、主题、网络层、共享模型
- 登录、手动录入、图片上传、OCR 确认、AI 确认、列表、详情、相似题、设置页面壳子
- 基于 `shared_preferences` 的本地草稿恢复与 API Base URL 覆盖

本机准备好 Flutter 与 Xcode 后，建议在本目录执行：

```bash
cp config/app_config.example.json config/app_config.json
flutter pub get
flutter devices
flutter run -d DEVICE_ID --dart-define=APP_FLAVOR=production
```

仓库已经包含 `ios/` 和 `android/` 原生工程，不要再次执行 `flutter create .`，以免覆盖项目已有的包名、权限和原生配置。

Android 构建前用 `flutter doctor -v` 确认 Flutter 实际使用的 Java。项目当前的 Gradle 8.10.2 不支持 Java 25；如果构建立即失败且 `What went wrong` 只有 `25.0.3`，请指定兼容的 JDK（正式流水线使用 JDK 17）：

```bash
flutter config --jdk-dir="/你的/JDK17/安装目录"
flutter build apk --release --dart-define=APP_FLAVOR=production
```

`--jdk-dir` 是本机 Flutter 配置，会影响本机其他 Flutter 项目；不要把机器专属路径写进仓库。仅设置 `JAVA_HOME` 不一定能覆盖 Flutter 选中的 Android Studio 内置 Java。依赖存在新版本及 iOS Swift Package Manager 的提示不是此次 Android 构建失败的原因。

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

- 正式应用包名沿用 `com.mathnotebook.mobile`：这是为兼容旧安装、保证升级被识别为同一应用而保留的安装标识
- Android 侧已补充 `INTERNET` 与安装更新相关权限
- 原生配置补充项见 [docs/IOS_SETUP.md](./docs/IOS_SETUP.md)
- 开发阶段默认地址会按设备类型选择：
  - Android 模拟器：`http://10.0.2.2:8080`
  - iOS 模拟器：`http://127.0.0.1:8080`
  - 真机：请在 `config/app_config.json` 或设置页填写宿主机局域网地址
