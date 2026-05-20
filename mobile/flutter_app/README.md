# Flutter Android Client

这个目录用于承载错题本项目的 Flutter Android 客户端。

当前已落地：

- `lib/` 下的应用骨架、路由、主题、网络层、共享模型
- 登录、手动录入、图片上传、OCR 确认、AI 确认、列表、详情、相似题、设置页面壳子
- 基于 `shared_preferences` 的本地草稿恢复与 API Base URL 覆盖

本机准备好 Flutter 后，建议在本目录执行：

```bash
copy config\\app_config.example.json config\\app_config.json
flutter create . --platforms=android
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

Android 侧已补充：

- 正式应用包名 `com.mathnotebook.mobile`
- 主 manifest 下的 `INTERNET` 权限
- 允许开发阶段访问本地 HTTP 后端的 cleartext/network security 配置
